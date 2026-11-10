-- QuestCompanion 2.14.0 : le décor du Voile d'hiver (WinterVeil.lua) :
-- fenêtre de la saison (bornes, nouvel an), réglage auto/on/off et /qc noel,
-- décor du carnet (guirlande, flocons, cadeau et renne autour du titre) et
-- du cadre du compagnon (guirlande 3D, flocons), seulement en Azeroth et
-- en saison ; glyphe du filet en boule de neige et retour du filet hors
-- saison ; scène de capture : boule de neige puis flocons ; images du client
-- seulement (FileDataID), rien de livré.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local WV = { saved = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel", "InCombatLockdown",
	"UnitAffectingCombat", "C_Texture", "time", "date" }
for _, name in ipairs(GLOBALS) do WV.saved[name] = rawget(_G, name) end
local ART = NS.WINTER_VEIL_ART
local LAY = NS.CARNET_LAYOUT
-- des horodatages (midi, heure locale)
local function At(year, month, day) return os.time({ year = year, month = month, day = day, hour = 12 }) end
local DEC20, JUL1 = At(2026, 12, 20), At(2026, 7, 1)

local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "captureResult", "captureNetButton",
	"captureToast", "captureStage" }
function WV.Reset(style, mode, now)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.captureStages = nil
	NS.uiStyleCache = {}
	NS.errors = {}
	NS.carnetMissing = {}
	NS.winterVeilShown = nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	_G.UnitName = function(unit) if unit == "player" then return "Dyokrion" end end
	_G.UnitFullName = function(unit) if unit == "player" then return "Dyokrion", "Aeternalis" end end
	_G.UnitExists = function(unit) return unit == "player" end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.date = WV.saved.date
	WV.now = now or DEC20
	_G.time = function(t) if t then return os.time(t) end return WV.now end
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:DB().winterVeil = mode
	NS:CompanionData().tutoDone = true
end
function WV.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = WV.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.captureStages = nil
	NS.uiStyleCache = {}
	NS:DB().winterVeil = nil
	NS.winterVeilShown = nil
	ResetWorld()
end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end
local function Shown(region) return region and region.shown == true end

-- 1. La saison --------------------------------------------------------------------------------------
do
	Say("-- voile d'hiver : la saison")
	WV.Reset()
	Check("[WV] fenêtre : du 15 décembre au 2 janvier", NS.WINTER_VEIL.from.month == 12 and NS.WINTER_VEIL.from.day == 15
		and NS.WINTER_VEIL.to.month == 1 and NS.WINTER_VEIL.to.day == 2)
	Check("[WV] 15 décembre et 31 décembre : en saison", NS:WinterVeilSeason(At(2026, 12, 15)) and NS:WinterVeilSeason(At(2026, 12, 31)))
	Check("[WV] 1er et 2 janvier (nouvel an franchi) : en saison", NS:WinterVeilSeason(At(2027, 1, 1)) and NS:WinterVeilSeason(At(2027, 1, 2)))
	Check("[WV] 14 décembre, 3 janvier, 1er juillet : hors saison", not NS:WinterVeilSeason(At(2026, 12, 14))
		and not NS:WinterVeilSeason(At(2027, 1, 3)) and not NS:WinterVeilSeason(JUL1))
	Check("[WV] sans argument : maintenant (time())", NS:WinterVeilSeason() == true)
	WV.now = JUL1
	Check("[WV] … et hors saison en juillet", NS:WinterVeilSeason() == false)
	_G.date = function() error("pas de date") end
	local ok, value = pcall(NS.WinterVeilSeason, NS, DEC20)
	Check("[WV] date() en panne : hors saison, sans erreur", ok and value == false)
	_G.date = function() return nil end
	Check("[WV] date() vide : hors saison", NS:WinterVeilSeason(DEC20) == false)
	WV.Done()
end

-- 2. Le réglage et la commande ------------------------------------------------------------------------
do
	Say("-- voile d'hiver : réglage et /qc noel")
	WV.Reset()
	Check("[WV] par défaut : automatique", NS:WinterVeilChoice() == "auto")
	Check("[WV] auto en saison, style Azeroth : décor", NS:WinterVeilActive() == true)
	WV.now = JUL1
	Check("[WV] auto hors saison : pas de décor", NS:WinterVeilActive() == false)
	NS:DB().winterVeil = "on"
	Check("[WV] toujours : décor même en juillet", NS:WinterVeilActive() == true)
	WV.now = DEC20
	NS:DB().winterVeil = "off"
	Check("[WV] jamais : pas de décor même en saison", NS:WinterVeilActive() == false)
	NS:DB().winterVeil = "bidon"
	Check("[WV] valeur inconnue : automatique", NS:WinterVeilChoice() == "auto")
	WV.Reset("sobre", "on")
	Check("[WV] style Sobre : jamais de décor (même forcé)", NS:WinterVeilActive() == false)

	WV.Reset()
	local row, styleIndex
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "companionMain" then
			for index, r in ipairs(page.rows) do
				if r.key == "companionStyle" then styleIndex = index end
				if r.key == "winterVeil" then row = r; row.index = index end
			end
		end
	end
	Check("[WV] réglage sous le style de l'interface (page Compagnon de route)", row and styleIndex and row.index == styleIndex + 1
		and row.kind == "action" and row.label == "OPT_WINTER_VEIL" and NS.L.OPT_WINTER_VEIL == "Décor du Voile d'hiver")
	local choices = row and row.choices() or {}
	Check("[WV] trois choix : Automatique (du 15 décembre au 2 janvier), Toujours, Jamais", #choices == 3
		and choices[1].value == "auto" and choices[1].label == "Automatique" and choices[1].hint == "du 15 décembre au 2 janvier"
		and choices[2].label == "Toujours" and choices[3].label == "Jamais")
	row.choose("off")
	Check("[WV] le réglage choisit (jamais)", NS:DB().winterVeil == "off" and row.current() == "off")
	Check("[WV] infobulle : rien en Azeroth", row.tooltip() == nil)

	NS.EXTRA_COMMANDS["noel"](NS, "on")
	Check("[WV] /qc noel on", NS:DB().winterVeil == "on")
	NS.EXTRA_COMMANDS["noel"](NS, "jamais")
	Check("[WV] /qc noel jamais (alias)", NS:DB().winterVeil == "off")
	NS.EXTRA_COMMANDS["noel"](NS, "toujours")
	Check("[WV] /qc noel toujours (alias)", NS:DB().winterVeil == "on")
	NS.EXTRA_COMMANDS["noel"](NS, "auto")
	Check("[WV] /qc noel auto", NS:DB().winterVeil == "auto")
	local before = NS:DB().winterVeil
	Check("[WV] /qc noel bidon : rien ne change", NS:WinterVeilCommand("bidon") == nil and NS:DB().winterVeil == before)
	Check("[WV] /qc noel sans mot : l'usage", NS:WinterVeilCommand("") == nil)
	local strings = NS.WINTER_VEIL_STRINGS
	local parity = strings ~= nil
	for k in pairs(strings and strings.fr or {}) do if not strings.en[k] then parity = false end end
	for k in pairs(strings and strings.en or {}) do if not strings.fr[k] then parity = false end end
	Check("[WV] chaînes FR/EN au complet", parity)
	WV.Done()
end

-- 3. Le cadre du compagnon ------------------------------------------------------------------------------
do
	Say("-- voile d'hiver : cadre du compagnon")
	WV.Reset(nil, "on")
	NS:CompanionUpdateVisibility()
	local frame = NS.companionFrame
	local d = frame and frame.wvDecor
	Check("[WV] compagnon Azeroth : décor montré, sans erreur", d and Shown(d) and frame.uiStyle == "azeroth" and NoErrors(),
		select(2, NoErrors()))
	local lights = d and d.lights
	Check("[WV] guirlande 3D : modèle sans souris, au ras du haut de l'anneau", lights and Shown(lights)
		and lights.mouseEnabled == false and lights.kind == "PlayerModel"
		and lights.lastPoint.relTo == frame and lights.lastPoint.relPoint == "TOP"
		and lights.lastPoint.y == NS.WINTER_VEIL_COMPANION.y and lights:GetWidth() == NS.WINTER_VEIL_COMPANION.w,
		lights and tostring(lights.kind))
	Check("[WV] guirlande au-dessus de l'anneau (habit), sous le calque des effets",
		lights and lights:GetFrameLevel() > frame.azSkin:GetFrameLevel() and lights:GetFrameLevel() < frame:GetFrameLevel() + 8)
	-- le client charge le modèle : SetModel(199600), cadrage posé
	lights.SetModel = function(m, id) m.loaded = id end
	lights.SetCamDistanceScale = function(m, v) m.cam = v end
	NS:WinterVeilCompanion()
	Check("[WV] guirlande : modèle 199600 chargé, caméra posée", lights.loaded == 199600 and lights.wvModel == 199600
		and lights.cam == NS.WINTER_VEIL_COMPANION.cam)
	Check("[WV] deux flocons (236121) près du cadre", #d.flakes == 2 and d.flakes[1].texture == ART.flake.file
		and d.flakes[2].texture == 236121 and d.flakes[1].alpha < 1)
	local gift = false
	for _, child in ipairs(d.mockChildren or {}) do if child.texture == 133202 then gift = true end end
	Check("[WV] pas de cadeau à côté du compagnon", not gift)
	-- jamais : caché tout de suite
	NS:SetWinterVeil("off")
	Check("[WV] jamais : décor du compagnon caché sans /reload", not Shown(d) and not Shown(lights))
	NS:SetWinterVeil("on")
	Check("[WV] toujours : il revient", Shown(d) and Shown(lights))
	-- style Sobre à chaud : caché
	NS:SetUIStyle("sobre")
	Check("[WV] style Sobre : décor du compagnon caché", not Shown(d) and frame.uiStyle == "sobre")
	NS:SetUIStyle("azeroth")
	Check("[WV] retour en Azeroth : décor revenu", Shown(d))
	-- automatique, hors saison
	NS:SetWinterVeil("auto")
	WV.now = JUL1
	NS:CompanionUpdateVisibility()
	Check("[WV] automatique hors saison : caché (au prochain affichage du compagnon)", not Shown(d))
	WV.now = DEC20
	NS:CompanionUpdateVisibility()
	Check("[WV] la saison commence : il revient", Shown(d))
	WV.Done()
end

-- 4. Le carnet -------------------------------------------------------------------------------------------
do
	Say("-- voile d'hiver : le carnet")
	WV.Reset(nil, "on")
	local f = NS:ToggleJournal(true)
	local d = f and f.wvDecor
	local ok, errs = NoErrors()
	Check("[WV] carnet Azeroth : décor montré, sans erreur", f and f.azeroth and d and Shown(d) and ok, errs)
	local inner = f:GetWidth() - 2 * LAY.wood
	local total, good = 0, #d.lights > 0
	for _, tex in ipairs(d.lights) do
		total = total + tex:GetWidth()
		if tex.texture ~= 235484 or tex:GetHeight() ~= NS.WINTER_VEIL_JOURNAL.lightsH then good = false end
	end
	local first = d.lights[1]
	Check("[WV] guirlande (235484) répétée d'un bord du bois à l'autre", good and math.abs(total - inner) < 0.01,
		tostring(total) .. " / " .. tostring(inner))
	Check("[WV] … sous la plaque (bande et métal), découpe du haut (104×36 sur 128)", first.lastPoint.y == -LAY.band
		and first.lastPoint.x == LAY.wood and first.texCoord[3] == 0 and math.abs(first.texCoord[4] - 36 / 128) < 1e-9
		and math.abs(first.texCoord[2] - 104 / 128) < 1e-9)
	local title = f.azPlate.title
	local half = title:GetStringWidth() / 2
	local size = NS.WINTER_VEIL_JOURNAL.iconSize
	Check("[WV] cadeau (133202) et renne (236707) autour du titre, sans le toucher", Shown(d.present) and Shown(d.reindeer)
		and d.present.texture == 133202 and d.reindeer.texture == 236707
		and d.present.lastPoint.relTo == title and -d.present.lastPoint.x - size / 2 >= half
		and d.reindeer.lastPoint.x - size / 2 >= half and d.present.texCoord[1] == 0.08,
		tostring(d.present.lastPoint.x) .. " / " .. tostring(half))
	local flakesOk = #d.flakes >= 3 and #d.flakes <= 4
	for _, tex in ipairs(d.flakes) do
		if tex.texture ~= 236121 or tex.alpha < 0.35 or tex.alpha > 0.45 or tex.drawLayer ~= "BORDER" or not Shown(tex) then flakesOk = false end
	end
	Check("[WV] 3 flocons blancs discrets (236121, alpha 0,35-0,45), sous les textes", flakesOk)
	Check("[WV] le décor ne prend pas la souris", d.mouseEnabled == false)
	-- jamais : caché sans rouvrir
	NS:SetWinterVeil("off")
	Check("[WV] jamais : décor du carnet caché tout de suite", not Shown(d) and not Shown(d.flakes[1]))
	NS:SetWinterVeil("on")
	Check("[WV] toujours : il revient", Shown(d) and Shown(d.flakes[1]))
	-- automatique hors saison, au rafraîchissement
	NS:DB().winterVeil = "auto"
	WV.now = JUL1
	NS:RefreshJournal()
	Check("[WV] automatique hors saison : caché au rafraîchissement", not Shown(d))
	WV.Done()

	-- le carnet Sobre : aucun décor
	WV.Reset("sobre", "on")
	local s = NS:ToggleJournal(true)
	Check("[WV] carnet Sobre : aucun décor", s and not s.azeroth and s.wvDecor == nil and NoErrors())
	WV.Done()
end

-- 5. La boule de neige -------------------------------------------------------------------------------------
do
	Say("-- voile d'hiver : la boule de neige")
	WV.Reset(nil, "on")
	local button = NS:EnsureCaptureNet()
	Check("[WV] bouton du filet : l'icône boule de neige (132387) pendant le décor", button.icon.texture == 132387
		and button.icon.texCoord[1] == 0.08)
	NS:SetWinterVeil("off")
	Check("[WV] hors décor : le filet du jeu revient sans /reload", button.icon.texture == "Interface\\Icons\\INV_Misc_Net_01",
		tostring(button.icon.texture))
	NS:SetWinterVeil("on")
	Check("[WV] … et la boule de neige revient", button.icon.texture == 132387)
	NS:SetUIStyle("sobre")
	Check("[WV] style Sobre : le filet", button.icon.texture == "Interface\\Icons\\INV_Misc_Net_01")
	NS:SetUIStyle("azeroth")
	local glyph = UIParent:CreateTexture(nil, "ARTWORK")
	NS.CapturePaintNetGlyph(glyph)
	Check("[WV] glyphe des bandeaux : boule de neige", glyph.texture == 132387)

	-- la scène : la boule vole, puis éclate en flocons ; filet et paquet cachés
	local start = Mock.now
	local stage = NS:CaptureShowStage({ target = { name = "Raptor", class = "normal", npcID = 7100 }, start = start, done = 0 })
	local ok = stage ~= nil
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME / 2)
	Check("[WV] scène : la boule de neige en vol (132387), pas de paquet ni de filet", ok and Shown(stage.wvBall)
		and stage.wvBall.texture == 132387 and not Shown(stage.bundle) and not Shown(stage.net) and not Shown(stage.netShadow))
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + NS.WINTER_VEIL_SNOWBALL.burst / 2)
	local flakes = stage.wvFlakes
	local burst = #flakes == NS.WINTER_VEIL_SNOWBALL.flakes
	for _, tex in ipairs(flakes) do if not Shown(tex) or tex.texture ~= 236121 or tex.alpha >= 0.9 then burst = false end end
	Check("[WV] à l'arrivée : la boule éclate en flocons qui s'effacent, filet toujours caché", burst and not Shown(stage.wvBall)
		and not Shown(stage.net) and not Shown(stage.netShadow))
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + NS.WINTER_VEIL_SNOWBALL.burst + 0.5)
	local gone = true
	for _, tex in ipairs(flakes) do if Shown(tex) then gone = false end end
	Check("[WV] puis les flocons disparaissent", gone)
	NS:CaptureHideStage()

	-- hors décor : le filet revient dans la scène
	NS:SetWinterVeil("off")
	stage = NS:CaptureShowStage({ target = { name = "Raptor", class = "normal", npcID = 7100 }, start = Mock.now, done = 0 })
	NS:CaptureStageUpdate(Mock.now + NS.CAPTURE_THROW_TIME * 0.9)
	Check("[WV] hors décor : paquet et filet, pas de boule de neige", Shown(stage.bundle) and Shown(stage.net)
		and not Shown(stage.wvBall))
	NS:CaptureHideStage()
	local errOk, errs = NoErrors()
	Check("[WV] la capture n'a levé aucune erreur", errOk, errs)
	WV.Done()
end

-- 5 bis. « Tout capturer » : une boule de neige par case ------------------------------------------------
do
	Say("-- voile d'hiver : tout capturer")
	local function Batch()
		local results = {
			{ target = { name = "Raptor", class = "normal", npcID = 7100 }, success = true, shakes = 3, stars = 1 },
			{ target = { name = "Loup", class = "normal", npcID = 7101 }, success = false, shakes = 1 },
		}
		local batch = { results = results, messages = {}, tried = 0 }
		NS.captureBatch = batch
		NS:CaptureBatchShow(batch)
		return batch
	end
	local function NetsHidden(batch)
		for _, card in ipairs(batch.cards) do
			local tile = card.tile
			if Shown(tile.net) or Shown(tile.shadow) then return false end
			for _, rope in ipairs(tile.ropes) do if Shown(rope) then return false end end
		end
		return true
	end
	WV.Reset(nil, "on")
	NS:DB().companionCaptureAnim = true
	local batch = Batch()
	local first = batch.cards[1]
	local drape = NS.CAPTURE_BATCH_DRAPE
	NS:CaptureBatchUpdate(batch.startedAt + first.dropAt + drape / 2)
	Check("[WV] volée : la boule de neige (132387) tombe sur la case, pas de filet", Shown(first.tile.wvBall)
		and first.tile.wvBall.texture == 132387 and NetsHidden(batch))
	NS:CaptureBatchUpdate(batch.startedAt + first.dropAt + drape + NS.WINTER_VEIL_SNOWBALL.burst / 2)
	local burst = #first.tile.wvFlakes == NS.WINTER_VEIL_SNOWBALL.tileFlakes
	for _, tex in ipairs(first.tile.wvFlakes) do if not Shown(tex) or tex.texture ~= 236121 then burst = false end end
	Check("[WV] volée : elle éclate en flocons, le filet reste caché (secousses)", burst and not Shown(first.tile.wvBall)
		and NetsHidden(batch))
	NS:CaptureBatchStop(true)
	local quiet = true
	for _, card in ipairs(batch.cards) do
		if Shown(card.tile.wvBall) then quiet = false end
		for _, tex in ipairs(card.tile.wvFlakes or {}) do if Shown(tex) then quiet = false end end
	end
	Check("[WV] volée arrêtée : verdicts figés, ni filet (même déchiré) ni neige qui reste", batch.done and quiet
		and NetsHidden(batch))
	local ok, errs = NoErrors()
	Check("[WV] volée : sans erreur", ok, errs)
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	NS.captureBatch = nil

	-- hors décor : le filet revient
	NS:SetWinterVeil("off")
	batch = Batch()
	first = batch.cards[1]
	NS:CaptureBatchUpdate(batch.startedAt + first.dropAt + drape / 2)
	Check("[WV] volée hors décor : le filet tombe, pas de boule de neige", Shown(first.tile.net)
		and not Shown(first.tile.wvBall))
	NS:CaptureBatchStop(true)
	local fled = batch.cards[2].tile
	Check("[WV] volée hors décor : filet déchiré sur l'échappée", Shown(fled.net))
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	NS.captureBatch = nil
	NS.captureBatchFrame, NS.captureBatchFrames = nil, nil
	WV.Done()
end

-- 6. Images du client seulement ----------------------------------------------------------------------------
do
	Say("-- voile d'hiver : images du client")
	local numbers = true
	for _, spec in pairs(NS.WINTER_VEIL_ART) do if type(spec.file) ~= "number" then numbers = false end end
	Check("[WV] toutes les images du décor sont des FileDataID du client", numbers and type(NS.WINTER_VEIL_COMPANION.model) == "number")
	Check("[WV] fichiers attendus : guirlande 235484, flocon 236121, cadeau 133202, renne 236707, boule 132387",
		ART.lights.file == 235484 and ART.flake.file == 236121 and ART.present.file == 133202
		and ART.reindeer.file == 236707 and ART.snowball.file == 132387)
end
