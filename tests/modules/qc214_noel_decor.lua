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
	local C, ring = NS.WINTER_VEIL_COMPANION, NS.AZEROTH_RING
	local box = NS.WinterVeilLightsBox()
	Check("[WV] guirlande 3D : modèles sans souris, sur le haut du cadre", lights and Shown(lights)
		and lights.mouseEnabled == false and lights.kind == "PlayerModel"
		and lights.lastPoint.relTo == frame and lights.lastPoint.relPoint == "TOP"
		and lights.lastPoint.y == C.y and lights:GetHeight() == C.h,
		lights and tostring(lights.kind))
	-- bêta 4 : deux brins, centrés sur le cadre (plus sur l'anneau décalé), toute la largeur de l'or
	local G = NS.WINTER_VEIL_RING_GOLD
	local swags = d.swags or {}
	local placed, sum = #swags == C.swags, 0
	for index, model in ipairs(swags) do
		sum = sum + model.lastPoint.x
		if not Shown(model) or math.abs(model.lastPoint.x - box.centers[index]) > 1e-6 then placed = false end
	end
	-- bêta 6 (31.png) : « une seule guirlande de cette taille, centrée »
	Check("[WV6] guirlande : un seul brin, centré sur le cadre (x = 0), d.lights", C.swags == 1 and placed
		and #swags == 1 and d.lights == swags[1] and swags[1].lastPoint.x == 0 and box.centers[1] == 0
		and NS.WINTER_VEIL_COMPANION_DEFAULT.swags == 1)
	-- bêta 7 (34.png) : le fil flottait au-dessus du bord doré : descendu de 9 px
	Check("[WV7] guirlande : descendue sur le bord doré du haut (y = -20, réglé en jeu), bulbes de 11,5 px, caméra 1,9, fit 3,5",
		C.y == -20 and swags[1].lastPoint.y == -20 and NS.WINTER_VEIL_COMPANION_DEFAULT.y == -20 and C.bulb == 11.5 and C.fit == 3.5
		and math.abs(box.cam - 1.9) < 0.01, string.format("%.3f", box.cam))
	Check("[WV4] guirlande : centrée sur le cadre (x = 0, pas le décalage de l'anneau)", C.x == 0
		and math.abs(sum / #swags) < 1e-6 and math.abs(box.left + box.right) < 1e-6, string.format("%.2f", sum))
	-- bêta 6 : un brin d'une soixantaine de px, au milieu de l'or (91 px)
	Check("[WV6] guirlande : un brin plus étroit que l'or, centré (bords symétriques)",
		box.w > 50 and box.w < G.w and math.abs(box.left + box.right) < 1e-6, string.format("%.1f", box.w))
	Check("[WV5] guirlande : bulbes moyens (11 à 13 px ; ~4 en bêta 4, ~18 en bêta 3)", box.bulb >= 11 and box.bulb <= 13,
		string.format("%.1f", box.bulb))
	Check("[WV5] guirlande : cadre de chaque brin assez large pour que la caméra le cadre sur sa hauteur (≥ fit × h)",
		C.fit >= 3 and lights:GetWidth() == box.frameW and box.frameW >= C.fit * C.h - 0.5 and box.frameW >= box.swag, string.format("%s / %s", tostring(lights:GetWidth()), tostring(box.frameW)))
	-- bêta 7 : le bord doré remesuré sur 34.png (de -5 à -17 sous le haut du cadre)
	Check("[WV141] bord doré du haut recalé sur le réglage en jeu : de -14 à -26", G.top == -14 and G.inner == -26)
	Check("[WV7] guirlande : le milieu du fil posé sur le bord doré du haut (dans sa moitié haute)",
		box.mid <= G.top and box.mid >= (G.top + G.inner) / 2, string.format("%.1f (%d..%d)", box.mid, G.inner, G.top))
	Check("[WV7] guirlande : bouts accrochés au-dessus de l'or, bulbes sur son bord et juste dans l'ouverture (≤ 5 px)",
		box.wire > G.top and box.bottom < G.inner and box.bottom >= G.inner - 5, string.format("%.1f / %.1f", box.wire, box.bottom))
	Check("[WV4] guirlande : caméra déduite de la taille de bulbe", math.abs(box.cam - C.h * C.bulbH / C.bulb) < 1e-9
		and box.cam > 1)
	Check("[WV] guirlande au-dessus de l'anneau (habit), sous le calque des effets",
		lights and lights:GetFrameLevel() > frame.azSkin:GetFrameLevel() and lights:GetFrameLevel() < frame:GetFrameLevel() + 8)
	-- le client charge le modèle : SetModel(199600), cadrage posé
	for _, model in ipairs(d.swags) do
		model.SetModel = function(m, id) m.loaded = id end
		model.SetCamDistanceScale = function(m, v) m.cam = v end
		model.wvModel = nil
	end
	NS:WinterVeilCompanion()
	Check("[WV] guirlande : modèle 199600 chargé, caméra posée", lights.loaded == 199600 and lights.wvModel == 199600
		and math.abs(lights.cam - NS.WinterVeilLightsBox().cam) < 1e-9)
	-- bêta 4 : le réglage en jeu (/qc noel cadre <bulbe> <x> <y> <brins> <cap>)
	local printed = {}
	local print0 = NS.Print
	NS.Print = function(_, text) printed[#printed + 1] = text end
	NS:WinterVeilCommand("cadre 10 -3 1 3 0.2")
	local tuned = NS.WinterVeilLightsBox()
	Check("[WV4] /qc noel cadre : valeurs posées et réappliquées tout de suite", C.bulb == 10 and C.x == -3 and C.y == 1
		and C.swags == 3 and C.facing == 0.2 and #d.swags == 3 and Shown(d.swags[3])
		and math.abs(d.swags[1].lastPoint.x - tuned.centers[1]) < 1e-6 and d.swags[1].lastPoint.y == 1
		and math.abs(lights.cam - tuned.cam) < 1e-9 and printed[1] and printed[1]:find("10", 1, true) ~= nil, printed[1])
	NS:WinterVeilCommand("cadre - - - 1")
	Check("[WV4] /qc noel cadre : « - » garde la valeur, un brin de moins se cache", C.bulb == 10 and C.swags == 1
		and Shown(d.swags[1]) and not Shown(d.swags[2]) and not Shown(d.swags[3]))
	NS:WinterVeilCommand("frame default")
	Check("[WV7] /qc noel frame default : valeurs livrées (un brin centré, y = -20)", C.bulb == NS.WINTER_VEIL_COMPANION_DEFAULT.bulb
		and C.swags == 1 and C.x == 0 and C.y == -20 and Shown(d.swags[1]) and d.swags[1].lastPoint.x == 0
		and d.swags[1].lastPoint.y == -20
		and not Shown(d.swags[2]) and not Shown(d.swags[3]))
	printed = {}
	NS:WinterVeilCommand("cadre")
	Check("[WV4] /qc noel cadre sans valeur : les valeurs actuelles, rien ne change", #printed == 1
		and C.bulb == NS.WINTER_VEIL_COMPANION_DEFAULT.bulb and C.bulb == 11.5)
	NS.Print = print0
	-- bêta 6 : « Tu devais pas mettre des flocons aussi ? » : quatre flocons aux coins, bien visibles
	local corners, visible = {}, true
	for index, tex in ipairs(d.flakes) do
		local spec = C.flakes[index]
		if tex.texture ~= ART.flake.file or tex.alpha < 0.85 or tex.width < 15 or not Shown(tex)
			or tex.lastPoint.relTo ~= frame or tex.lastPoint.x ~= spec.x then visible = false end
		corners[(spec.x < 0 and "G" or "D") .. (spec.y > -40 and "H" or "B")] = true
	end
	Check("[WV6] quatre flocons fixes (236121) aux coins du cadre, hors de l'anneau, grands et presque opaques",
		#d.flakes == 4 and visible and corners.GH and corners.DH and corners.GB and corners.DB)
	local gift = false
	for _, child in ipairs(d.mockChildren or {}) do if child.texture == 133202 then gift = true end end
	Check("[WV] pas de cadeau à côté du compagnon", not gift)
	-- bêta 5 (26.png) : mode voyage, interface cachée : l'habit du cadre ne se
	-- voit plus (opacité effective nulle), les modèles 3D, eux, si : la
	-- guirlande et les flocons se cachent avec l'habit, et reviennent avec lui
	local function DecorOn()
		if not (Shown(d.flakes[1]) and Shown(d.flakes[2])) then return false end
		for index = 1, C.swags do if not Shown(d.swags[index]) then return false end end
		return true
	end
	local function DecorOff()
		for _, tex in ipairs(d.flakes) do if Shown(tex) then return false end end
		for _, model in ipairs(d.swags) do if Shown(model) then return false end end
		return true
	end
	Check("[WV5] habit visible : guirlande et flocons là, rien à reprendre", DecorOn() and NS:WinterVeilWatch() == false
		and d.bare == false)
	UIParent:SetAlpha(0)
	Check("[WV5] interface cachée (opacité 0) : l'habit est nu", NS:WinterVeilCompanionBare(frame) == true)
	Check("[WV5] … le guet le voit : guirlande 3D et flocons cachés, décor gardé", NS:WinterVeilWatch() == true
		and DecorOff() and Shown(d) and d.bare == true)
	Check("[WV5] … et ne refait rien tant que rien ne change", NS:WinterVeilWatch() == false and DecorOff())
	NS:WinterVeilCompanion()
	Check("[WV5] … un rafraîchissement du compagnon ne les remontre pas", DecorOff())
	UIParent:SetAlpha(1)
	Check("[WV5] interface revenue : guirlande et flocons reviennent", NS:WinterVeilWatch() == true and DecorOn())
	-- l'opacité du client (GetEffectiveAlpha) quand il la donne ; le combat (0,35) n'est pas « nu »
	frame.azSkin.GetEffectiveAlpha = function() return NS.COMPANION_COMBAT_ALPHA end
	Check("[WV5] combat estompé (0,35) : la guirlande reste", NS:WinterVeilWatch() == false and DecorOn())
	frame.azSkin.GetEffectiveAlpha = function() return 0 end
	Check("[WV5] GetEffectiveAlpha à 0 : cachée", NS:WinterVeilWatch() == true and DecorOff())
	frame.azSkin.GetEffectiveAlpha = nil
	NS:WinterVeilWatch()
	-- l'habit caché (cadre d'un autre style, interface masquée) : cachée aussi
	frame.azSkin:Hide()
	Check("[WV5] habit caché : guirlande cachée", NS:WinterVeilWatch() == true and DecorOff())
	frame.azSkin:Show()
	Check("[WV5] habit remontré : elle revient", NS:WinterVeilWatch() == true and DecorOn())
	local everyOk = false
	local count, order = NS.ClockJobs()
	for index = 1, count do if order[index] == "noel:cadre" then everyOk = true end end
	Check("[WV5] le guet tourne sur l'horloge de l'addon (noel:cadre, 0,25 s)", everyOk and NS.WINTER_VEIL_BARE_STEP == 0.25)
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
	-- bêta 5 (29.png) : une seule bande, d'un bord intérieur du bois à l'autre, par-dessus le joint
	local J = NS.WINTER_VEIL_JOURNAL
	Check("[WV3] guirlande plus grande : bande de 24 à 30 px", J.lightsH >= 24 and J.lightsH <= 30)
	local min, max, total, good, shown = math.huge, -math.huge, 0, #d.lights > 0, 0
	local xs = {}
	for _, tex in ipairs(d.lights) do
		if Shown(tex) then
			shown = shown + 1
			total = total + tex:GetWidth()
			min = math.min(min, tex.lastPoint.x)
			max = math.max(max, tex.lastPoint.x + tex:GetWidth())
			xs[#xs + 1] = { x = tex.lastPoint.x, w = tex:GetWidth() }
			if tex.texture ~= 235484 or tex:GetHeight() ~= J.lightsH or tex.lastPoint.y ~= -LAY.band
				or tex.lastPoint.point ~= "TOPLEFT" or tex.lastPoint.relTo ~= f or tex:GetParent() ~= d then good = false end
		end
	end
	table.sort(xs, function(a, b) return a.x < b.x end)
	local continuous = #xs > 0
	for index = 2, #xs do if math.abs(xs[index].x - (xs[index - 1].x + xs[index - 1].w)) > 0.01 then continuous = false end end
	local W = f:GetWidth()
	Check("[WV5] guirlande (235484) : une seule bande sur le décor, ancrée au cadre, pendue au bas de la barre de métal",
		good and shown == #d.lights and d:GetFrameLevel() > f.azOver:GetFrameLevel())
	Check("[WV5] bande continue, sans trou (joint compris)", continuous and math.abs(total - (max - min)) < 0.01)
	local jointX = LAY.wood + LAY.nav + LAY.gap / 2
	Check("[WV5] d'un bord intérieur du bois à l'autre, marges égales de 6 à 10 px, par-dessus le poteau du joint",
		math.abs(min - (LAY.wood + J.lightsEdge)) < 0.01 and math.abs((W - LAY.wood) - max - J.lightsEdge) < 0.01
		and J.lightsEdge >= 6 and J.lightsEdge <= 10 and min < jointX - 20 and max > jointX + 20
		and math.abs((min - LAY.wood) - ((W - LAY.wood) - max)) < 0.01, string.format("%.1f..%.1f / %d", min, max, W))
	Check("[WV5] du début de la colonne à la fin de la page", min - LAY.wood <= 10
		and (f.nav:GetWidth() + LAY.gap + f.content:GetWidth()) - (max - LAY.wood) <= 10)
	-- reposée au rafraîchissement : même nombre de tuiles, rien de recréé
	local before = #d.lights
	NS:WinterVeilJournal(f)
	Check("[WV5] rafraîchie : les mêmes tuiles reposées", #d.lights == before and d.lightsCount == before)
	-- les flocons restent visibles sous la bande (pas dans ses 28 px)
	local flakesBelow = true
	for _, tex in ipairs(d.flakes) do
		if tex.lastPoint.y + tex.wvSpec.size / 2 > -J.lightsH then flakesBelow = false end
	end
	Check("[WV5] les flocons sous la bande, pas recouverts", flakesBelow)
	Check("[WV4] l'intitulé « CARNET », sous la guirlande, est caché", not f.navGroup:IsShown())
	local first = d.lights[1]
	Check("[WV] … découpe du haut (104×36 sur 128)", first.texCoord[3] == 0 and math.abs(first.texCoord[4] - 36 / 128) < 1e-9
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
	Check("[WV] jamais : décor du carnet caché tout de suite", not Shown(d) and not Shown(d.flakes[1])
		and not Shown(d.lights[1]) and not Shown(d.lights[#d.lights]))
	Check("[WV4] jamais : l'intitulé « CARNET » revient", f.navGroup:IsShown())
	NS:SetWinterVeil("on")
	Check("[WV] toujours : il revient", Shown(d) and Shown(d.flakes[1]) and Shown(d.lights[1]))
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
	-- (bêta 3 : un client qui sait masquer, pour voir la boule arrondie)
	local start = Mock.now
	local masks = {}
	local mockCreateFrame = _G.CreateFrame
	_G.CreateFrame = function(...)
		local made = mockCreateFrame(...)
		function made:CreateMaskTexture()
			local mask = self:CreateTexture(nil, "ARTWORK")
			function mask:SetTexture(file, h, v) self.texture, self.wrap = file, { h, v } end
			masks[#masks + 1] = mask
			return mask
		end
		local base = made.CreateTexture
		function made:CreateTexture(...)
			local tex = base(self, ...)
			function tex:AddMaskTexture(mask) self.masks = self.masks or {}; self.masks[#self.masks + 1] = mask end
			return tex
		end
		return made
	end
	NS.captureStages, NS.captureStage = nil, nil
	local stage = NS:CaptureShowStage({ target = { name = "Raptor", class = "normal", npcID = 7100 }, start = start, done = 0 })
	_G.CreateFrame = mockCreateFrame
	local ok = stage ~= nil
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME / 2)
	Check("[WV] scène : la boule de neige en vol (132387), pas de paquet ni de filet", ok and Shown(stage.wvBall)
		and stage.wvBall.texture == 132387 and not Shown(stage.bundle) and not Shown(stage.net) and not Shown(stage.netShadow))
	local ball, B = stage.wvBall, ART.ball
	local mask = ball.masks and ball.masks[1]
	Check("[WV3] boule lancée : découpée autour de la boule (plus les coins sombres de l'icône)", ball.texCoord[1] == B.c[1]
		and ball.texCoord[2] == B.c[2] and ball.texCoord[3] == B.c[3] and ball.texCoord[4] == B.c[4]
		and B.c[2] - B.c[1] <= 0.6 and math.abs((B.c[2] - B.c[1]) - (B.c[4] - B.c[3])) < 1e-9)
	Check("[WV3] boule lancée : arrondie par le masque rond du client, qui la suit", mask ~= nil
		and mask.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask" and mask.allPoints == ball)
	local S = NS.WINTER_VEIL_SNOWBALL
	local early = (function()
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME * 0.1)
		return ball:GetWidth()
	end)()
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME * 0.9)
	local late = ball:GetWidth()
	local trail = 0
	for _, tex in ipairs(stage.wvTrail) do if Shown(tex) and tex.texture == 236121 then trail = trail + 1 end end
	Check("[WV3] vol : la boule rapetisse en s'éloignant, tourne un peu", early > late and late >= S.size * S.scaleTo - 0.01
		and ball.rotation ~= nil and ball.rotation <= math.pi * S.spin)
	Check("[WV3] vol : une traîne de petits flocons derrière elle", trail == S.trail and S.trailSize < S.size / 2)
	-- 2.14.0 (bêta 3) : sur la carte de parchemin, la boule arrive sur la créature (centre de la scène)
	Check("[WV3] pied : « La boule de neige vole… »", stage.footer:GetText() == NS.L.WINTER_VEIL_STAGE_FLY
		and NS.WINTER_VEIL_STRINGS.en.WINTER_VEIL_STAGE_FLY ~= nil)
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME * 0.999)
	local hit, body = ball.lastPoint, stage.model.lastPoint
	Check("[WV3] carte de parchemin : la boule finit sa course sur la créature", stage.chrome == "card"
		and hit.relTo == stage.scene and math.abs(hit.x) < 2 and math.abs(hit.y) < 2
		and body.relTo == stage.scene and body.x == 0 and body.y == 0, hit.x .. "," .. hit.y)
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + S.burst * 0.1)
	Check("[WV3] pied après l'impact : « Sous la neige, ça remue… »", stage.footer:GetText() == NS.L.WINTER_VEIL_STAGE_SHAKE)
	local puff = stage.wvPuff
	Check("[WV3] impact : une bouffée de neige (boule additive, arrondie) qui grandit", Shown(puff) and puff.blendMode == "ADD"
		and puff.masks ~= nil and puff:GetWidth() > S.size * S.scaleTo)
	local trailGone = true
	for _, tex in ipairs(stage.wvTrail) do if Shown(tex) then trailGone = false end end
	Check("[WV3] impact : la traîne disparaît", trailGone)
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + NS.WINTER_VEIL_SNOWBALL.burst / 2)
	local flakes = stage.wvFlakes
	local burst = #flakes == NS.WINTER_VEIL_SNOWBALL.flakes
	for _, tex in ipairs(flakes) do if not Shown(tex) or tex.texture ~= 236121 or tex.alpha >= 0.9 then burst = false end end
	Check("[WV] à l'arrivée : la boule éclate en flocons qui s'effacent, filet toujours caché", burst and not Shown(stage.wvBall)
		and not Shown(stage.net) and not Shown(stage.netShadow))
	NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + NS.WINTER_VEIL_SNOWBALL.burst + 0.5)
	local gone = true
	for _, tex in ipairs(flakes) do if Shown(tex) then gone = false end end
	Check("[WV] puis les flocons disparaissent", gone and not Shown(stage.wvPuff))
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
	Check("[WV3] volée : la boule découpée autour d'elle aussi", first.tile.wvBall.texCoord[1] == ART.ball.c[1]
		and first.tile.wvBall.texCoord[4] == ART.ball.c[4])
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

-- 5 bis. Bêta 6 : la neige qui tombe et le cadre givré --------------------------------------------------
do
	Say("-- voile d'hiver (bêta 6) : neige qui tombe, cadre givré")
	WV.Reset(nil, "on")
	-- le client sait boucler un groupe d'animations (SetLooping) : posé sur
	-- les textures des cadres créés ici (le banc de base ne l'a pas : socle_211)
	local createFrame = _G.CreateFrame
	_G.CreateFrame = function(...)
		local made = createFrame(...)
		local create = made.CreateTexture
		if create then
			made.CreateTexture = function(self, ...)
				local tex = create(self, ...)
				local group = tex.CreateAnimationGroup
				tex.CreateAnimationGroup = function(t)
					local g = group(t)
					function g:SetLooping(v) self.looping = v end
					return g
				end
				return tex
			end
		end
		return made
	end
	NS:CompanionUpdateVisibility()
	_G.CreateFrame = createFrame
	local frame = NS.companionFrame
	local d = frame and frame.wvDecor
	local S = NS.WINTER_VEIL_COMPANION.snow
	local function Snowing()
		if #d.snow == 0 then return false end
		for _, tex in ipairs(d.snow) do
			if not (Shown(tex) and tex.wvAnim and tex.wvAnim.playing) then return false end
		end
		return d.snowing == true
	end
	local function SnowStopped()
		for _, tex in ipairs(d.snow) do
			if Shown(tex) or (tex.wvAnim and tex.wvAnim.playing) then return false end
		end
		return d.snowing == false
	end
	Check("[WV6] neige : 4 à 6 petits flocons (236121) qui tombent autour du cadre, sans erreur",
		d and #d.snow >= 4 and #d.snow <= 6 and Snowing() and NoErrors(), select(2, NoErrors()))
	local anims, delays, distinct = true, {}, 0
	for index, tex in ipairs(d.snow) do
		local g, spec = tex.wvAnim, S[index]
		if not (g and g.looping == "REPEAT" and tex.texture == ART.flake.file and tex.alpha == 0 and tex.width <= 10
			and tex.lastPoint.relTo == frame and tex.lastPoint.x == spec.x and tex.lastPoint.y == S.top
			and g.fall.kind == "Translation" and g.fall.offset[1] == spec.dx and g.fall.offset[2] == -S.fall
			and g.fall.duration == spec.time and g.fall.startDelay == spec.delay
			and g.fadeIn.kind == "Alpha" and g.fadeIn.from == 0 and g.fadeIn.to == S.alpha and g.fadeIn.startDelay == spec.delay
			and g.fadeOut.kind == "Alpha" and g.fadeOut.from == S.alpha and g.fadeOut.to == 0
			and math.abs(g.fadeOut.startDelay + g.fadeOut.duration - spec.delay - spec.time) < 1e-9) then anims = false end
		if not delays[spec.delay] then delays[spec.delay] = true; distinct = distinct + 1 end
	end
	Check("[WV6] neige : chaque flocon en boucle (translation vers le bas + fondus), transparent au repos", anims)
	Check("[WV6] neige : décalée dans le temps (attentes toutes différentes), lente (≥ 5 s par chute)",
		distinct == #d.snow and S[1].time >= 5 and S.fall >= 60)
	Check("[WV6] neige : sans OnUpdate (animations du client seulement)", not (d.scripts and d.scripts.OnUpdate)
		and not (d.hooks and d.hooks.OnUpdate))
	local plays = d.snow[1].wvAnim.plays
	NS:WinterVeilCompanion()
	Check("[WV6] neige : un rafraîchissement ne la relance pas", d.snow[1].wvAnim.plays == plays and Snowing())
	-- combat : le compagnon s'estompe, la neige s'arrête ; les flocons fixes restent
	_G.InCombatLockdown = function() return true end
	Check("[WV6] combat (compagnon estompé) : la neige s'arrête, flocons fixes et guirlande gardés",
		NS:WinterVeilWatch() == true and SnowStopped() and Shown(d.flakes[1]) and Shown(d.swags[1]))
	Check("[WV6] combat : rien de refait tant que rien ne change", NS:WinterVeilWatch() == false and SnowStopped())
	NS:DB().companionCombatFade = false
	Check("[WV6] combat sans estompe (réglage coupé) : la neige tombe", NS:WinterVeilWatch() == true and Snowing())
	NS:DB().companionCombatFade = nil
	NS:WinterVeilWatch()
	_G.InCombatLockdown = function() return false end
	NS.companionFighting = nil
	Check("[WV6] fin du combat : la neige reprend", NS:WinterVeilWatch() == true and Snowing())
	-- mode voyage (habit invisible) : cachée, puis revenue
	UIParent:SetAlpha(0)
	Check("[WV6] mode voyage : neige cachée", NS:WinterVeilWatch() == true and SnowStopped())
	UIParent:SetAlpha(1)
	Check("[WV6] interface revenue : la neige retombe", NS:WinterVeilWatch() == true and Snowing())

	-- le cadre givré (bêta 7 : l'allure Azeroth du cadre Givre, AZEROTH_RING_TINTS.frost)
	local ring = frame.azSkin.ring
	local F = NS.AZEROTH_RING_TINTS.frost
	local glow = frame.azRingGlow
	-- visible jusqu'à l'habit compris (le cadre du compagnon lui-même mis à part)
	local function Visible(region)
		local node = region
		while node and node ~= frame do
			if node.shown == false then return false end
			node = node.mockParent
		end
		return region ~= nil and region.shown == true
	end
	local function Gold(tex) return tex.vertex[1] == 1 and tex.vertex[2] == 1 and tex.vertex[3] == 1 and tex.vertex[4] == 1 and tex.azDesat == false end
	Check("[WV6] givre : réglage par défaut actif", NS:WinterVeilFrostOn() == true and NS:DB().winterVeilFrost ~= false)
	Check("[WV7] givre : l'anneau du portrait désaturé, teinté argent-bleu (allure du cadre Givre)", ring.vertex and ring.vertex[1] == F[1]
		and ring.vertex[2] == F[2] and ring.vertex[3] == F[3] and ring.azDesat == true and ring.azLook == "frost",
		ring.vertex and table.concat(ring.vertex, ","))
	local holder = glow and glow.holder
	local modelLevel = frame.model and frame.model.GetFrameLevel and frame.model:GetFrameLevel()
	Check("[WV7] givre : halo glacé du client en ADD, sous le modèle, sur l'habit (caché avec lui)",
		glow and holder and Visible(glow) and glow.atlas == "Relic-Frost-TraitGlowRing" and glow.drawLayer == "BACKGROUND"
		and glow.blendMode == "ADD" and holder:GetParent() == frame.azSkin and (holder:GetFrameLevel() or 0) < (modelLevel or 99)
		and glow.lastPoint.relTo == frame and glow.width > NS.AZEROTH_RING.w and glow.vertex and glow.vertex[3] == F.glow[3],
		string.format("%s %s %s %s %s", tostring(glow and glow.shown), tostring(holder and holder.shown),
			tostring(glow and glow.blendMode), tostring(holder and holder:GetFrameLevel()), tostring(modelLevel)))
	-- le réglage (page Compagnon de route, juste sous le décor)
	local row, at, decorAt
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionMain" then
			for index, r in ipairs(page.rows) do
				if r.key == "winterVeilFrost" then row, at = r, index end
				if r.key == "winterVeil" then decorAt = index end
			end
		end
	end
	Check("[WV6] réglage « Cadre givré (Voile d'hiver) » : case à cocher sous le décor du Voile d'hiver",
		row and row.kind == "bool" and at == decorAt + 1 and NS.L[row.label] == "Cadre givré (Voile d'hiver)"
		and NS.WINTER_VEIL_STRINGS.en.OPT_WINTER_VEIL_FROST ~= nil and row.describe() ~= nil)
	NS:DB().winterVeilFrost = false
	row.onChange()
	local curFrame = NS:CompanionCurrentStyle("frame").id
	Check("[WV7] givre coupé : l'anneau prend la teinte du cadre choisi, halo caché, décor gardé",
		ring.azLook == (NS.AZEROTH_RING_TINTS[curFrame] and curFrame or nil)
		and not Visible(glow) and Shown(d) and Snowing())
	NS:CompanionData().unlocked["frame:copper"] = true
	NS:CompanionSetStyle("frame", "copper")
	Check("[WV7] givre coupé, Cuivre choisi : l'anneau cuivré", ring.azLook == "copper" and ring.vertex[2] == NS.AZEROTH_RING_TINTS.copper[2])
	NS:DB().winterVeilFrost = true
	-- 2.14.1 : Cuivre a été choisi pendant le décor : il l'emporte sur Givre
	row.onChange()
	Check("[WV141] cadre choisi pendant la saison : il l'emporte sur l'allure Givre", ring.azLook == "copper"
		and NS:CompanionData().winterFrameChoice == true)
	-- sans choix pendant la saison : Givre par défaut
	NS:CompanionData().winterFrameChoice = nil
	row.onChange()
	Check("[WV7] givre remis : l'allure Givre l'emporte sur le cadre choisi pendant le décor", ring.azLook == "frost"
		and ring.vertex[1] == F[1] and Visible(glow) and NS:CompanionCurrentStyle("frame").id == "copper")
	-- mode voyage : le halo (sur l'habit) se cache avec l'habit
	frame.azSkin:Hide()
	NS:WinterVeilWatch()
	Check("[WV6] habit caché : halo caché aussi", not Visible(glow))
	frame.azSkin:Show()
	NS:WinterVeilWatch()
	Check("[WV6] habit revenu : halo revenu", Visible(glow))
	-- hors décor : tout revient
	NS:SetUIStyle("sobre")
	Check("[WV7] Sobre : anneau rendu à l'or, halo et neige cachés", Gold(ring) and not Visible(glow) and SnowStopped())
	NS:SetUIStyle("azeroth")
	Check("[WV6] retour en Azeroth : givre et neige revenus", ring.vertex[1] == F[1] and Visible(glow) and Snowing())
	NS:SetWinterVeil("off")
	Check("[WV7] jamais : l'anneau à la teinte du cadre choisi (Cuivre), halo et neige cachés", ring.azLook == "copper"
		and not Visible(glow) and SnowStopped())
	NS:SetWinterVeil("auto")
	WV.now = JUL1
	NS:CompanionUpdateVisibility()
	Check("[WV7] hors saison : l'anneau du cadre choisi", ring.azLook == "copper" and not Visible(glow) and SnowStopped())
	NS:CompanionData().unlocked["frame:copper"] = nil
	NS:CompanionData().frameStyle = nil
	WV.Done()

	-- atlas du halo absents : rien posé, sans erreur, la teinte reste
	WV.Reset(nil, "on")
	Mock.InstallAtlas({ ["Relic-Frost-TraitGlowRing"] = true })
	NS:AzerothAtlasOK(true)
	NS:CompanionUpdateVisibility()
	frame = NS.companionFrame
	-- (vérifié en jeu : l'anneau Kyrian est doré, il n'est plus un repli)
	Check("[WV6] halo de glace absent : pas d'anneau Kyrian en repli", frame.azRingGlow == false
		and NS.AZEROTH_RING_GLOW.atlases[1] == "Relic-Frost-TraitGlowRing" and #NS.AZEROTH_RING_GLOW.atlases == 1,
		tostring(frame.azRingGlow and frame.azRingGlow.atlas))
	local skinRing = frame.azSkin and frame.azSkin.ring
	Check("[WV6] aucun halo dans le client : rien posé, pas d'erreur, l'anneau givré quand même", frame.azRingGlow == false
		and skinRing and skinRing.vertex and skinRing.vertex[1] == F[1] and NoErrors(), select(2, NoErrors()))
	NS:SetWinterVeil("off")
	Check("[WV6] aucun halo : couleurs rendues sans erreur (Ardoise : gris, 2.14.1)", skinRing and skinRing.azLook == "slate" and NoErrors())
	WV.Done()
end

-- 5 ter. Bêta 7 : le cadre choisi colore l'anneau, Givre offert pendant la saison ---------------------
do
	Say("-- voile d'hiver (bêta 7) : teinte de l'anneau par cadre, Givre offert")
	local TINTS = NS.AZEROTH_RING_TINTS
	-- chaque cadre du catalogue : sa teinte (ou l'or d'origine)
	WV.Reset(nil, "off")
	NS:CompanionUpdateVisibility()
	local frame = NS.companionFrame
	local ring = frame.azSkin.ring
	local data = NS:CompanionData()
	local painted, missing = true, {}
	for _, def in ipairs(NS.COMPANION_FRAMES) do
		data.unlocked["frame:" .. def.id] = true
		local set = NS:CompanionSetStyle("frame", def.id)
		local look = TINTS[def.id]
		if not look and def.id:find("^seal_") then look = { def.edge[1], def.edge[2], def.edge[3], desat = true } end
		local r, g, b = 1, 1, 1
		if look and look[1] then r, g, b = look[1], look[2], look[3] end
		if not (set and ring.vertex[1] == r and ring.vertex[2] == g and ring.vertex[3] == b
			and ring.azDesat == ((look and look.desat) and true or false)
			and ring.azLook == (look and def.id or nil)) then
			painted = false; missing[#missing + 1] = def.id
		end
		data.unlocked["frame:" .. def.id] = nil
	end
	Check("[WV7] Azeroth : chaque cadre colore l'anneau (teinte, désaturation), sans erreur", painted and NoErrors(),
		table.concat(missing, ",") .. " " .. select(2, NoErrors()))
	-- la palette demandée
	local function Desat(id) return TINTS[id] and TINTS[id].desat == true end
	Check("[WV141] palette : Ardoise (défaut) en gris ardoise, Insigne du dresseur à l'or d'origine", TINTS.slate and TINTS.slate.desat and TINTS.trainer == nil
		and NS.COMPANION_FRAMES[1].id == "slate")
	Check("[WV7] palette : argent, givre, runique, gangrené, chêne désaturés ; cuivre et or ciselé sur l'or",
		Desat("silver") and Desat("frost") and Desat("rune") and Desat("fel") and Desat("oak")
		and not Desat("copper") and not Desat("gilded"))
	Check("[WV7] palette : Givre argent-bleu, Runique bleu-violet, Gangrené vert, Cuivre cuivré",
		TINTS.frost[3] > TINTS.frost[1] and TINTS.rune[3] > TINTS.rune[2] and TINTS.rune[1] > TINTS.rune[2] - 0.1
		and TINTS.fel[2] > TINTS.fel[1] and TINTS.fel[2] > TINTS.fel[3] and TINTS.copper[1] > TINTS.copper[2]
		and TINTS.copper[2] > TINTS.copper[3])
	Check("[WV7] palette : Étincelant et Givre ont un halo (doré, glacé)", TINTS.sparkle.glow and TINTS.frost.glow
		and TINTS.sparkle.glow[1] > TINTS.sparkle.glow[3] and TINTS.frost.glow[3] > TINTS.frost.glow[1])
	-- Étincelant : l'or d'origine, plus le halo doré
	data.unlocked["frame:sparkle"] = true
	NS:CompanionSetStyle("frame", "sparkle")
	local glow = frame.azRingGlow
	Check("[WV7] Étincelant : or clair (2.14.1) et halo doré autour de l'anneau", ring.vertex[2] == TINTS.sparkle[2] and ring.azDesat == false
		and glow and glow.shown and glow.vertex[1] == TINTS.sparkle.glow[1] and ring.azLook == "sparkle")
	NS:CompanionSetStyle("frame", "slate")
	Check("[WV141] retour à Ardoise : gris ardoise, halo caché", ring.vertex[1] == TINTS.slate[1] and ring.azDesat == true
		and not glow.shown and ring.azLook == "slate")
	data.unlocked["frame:sparkle"] = nil
	-- le grand portrait de la page Créature : même teinte
	data.unlocked["frame:fel"] = true
	NS:CompanionSetStyle("frame", "fel")
	local vine = { SetVertexColor = function(t, r, g, b, a) t.vertex = { r, g, b, a } end }
	local journal = { evo = { azVine = vine } }
	Check("[WV7] carnet : le portrait de la page Créature à la teinte du cadre (Gangrené)", NS:CarnetPaintRing(journal) == "fel"
		and vine.vertex[2] == TINTS.fel[2] and vine.azDesat == true)
	NS:CompanionSetStyle("frame", "slate")
	Check("[WV141] carnet : Ardoise en gris ardoise", NS:CarnetPaintRing(journal) == "slate" and vine.vertex[1] == TINTS.slate[1] and vine.azDesat == true)
	data.unlocked["frame:fel"] = nil
	-- Sobre : rien ne change (bordure du client, anneau à l'or et caché)
	data.unlocked["frame:rune"] = true
	NS:CompanionSetStyle("frame", "rune")
	NS:SetUIStyle("sobre")
	Check("[WV7] Sobre inchangé : bordure du client du cadre Runique, anneau rendu à l'or",
		frame.frameStyle == "rune" and frame.styleBorder and frame.styleBorder.shown and ring.vertex[1] == 1 and ring.azDesat == false
		and ring.azLook == nil)
	NS:SetUIStyle("azeroth")
	data.unlocked["frame:rune"] = nil
	data.frameStyle = nil
	WV.Done()

	-- Givre offert pendant la saison, repris après
	local frost
	for _, def in ipairs(NS.COMPANION_FRAMES) do if def.id == "frost" then frost = def end end
	WV.Reset(nil, "auto", JUL1)
	data = NS:CompanionData()
	data.unlocked["frame:frost"] = nil
	Check("[WV7] hors saison : Givre verrouillé (palier 2)", not NS:CompanionIsUnlocked("frame", frost)
		and not NS:CompanionSetStyle("frame", "frost"))
	WV.now = DEC20
	Check("[WV7] en saison : Givre offert, marqué « Voile d'hiver » dans la liste", NS:CompanionIsUnlocked("frame", frost)
		and not NS:WinterVeilGiftEarned())
	local entry
	for _, e in ipairs(NS:CompanionChoices("frame")) do if e.value == "frost" then entry = e end end
	Check("[WV7] liste des cadres : Givre choisissable, indice « Voile d'hiver »", entry and not entry.disabled
		and entry.hint == "Voile d'hiver" and NS.WINTER_VEIL_STRINGS.en.WINTER_VEIL_FROST_GIFT == "Winter Veil")
	data.unlocked["frame:copper"] = true
	NS:CompanionSetStyle("frame", "copper")
	NS:CompanionSetStyle("frame", "frost")
	Check("[WV7] Givre choisi grâce à la saison : le cadre d'avant gardé (Cuivre)", NS:CompanionCurrentStyle("frame").id == "frost"
		and data.frameBeforeGift == "copper")
	WV.now = At(2027, 1, 3)
	Check("[WV7] saison finie, Givre pas gagné : retour au cadre d'avant", NS:CompanionCurrentStyle("frame").id == "copper"
		and data.frameStyle == "copper" and data.frameBeforeGift == nil)
	-- /qc noel on (forcé) : offert hors saison aussi
	NS:DB().winterVeil = "on"
	Check("[WV7] /qc noel on : Givre offert hors saison", NS:CompanionIsUnlocked("frame", frost))
	NS:DB().winterVeil = "auto"
	-- gagné au coffre : reste à lui hors saison
	WV.now = DEC20
	NS:CompanionSetStyle("frame", "frost")
	data.unlocked["frame:frost"] = true
	WV.now = JUL1
	Check("[WV7] Givre gagné : gardé hors saison", NS:CompanionIsUnlocked("frame", frost) and NS:WinterVeilGiftEarned()
		and NS:CompanionCurrentStyle("frame").id == "frost" and data.frameBeforeGift == nil)
	-- Givre (gagné) porté hors saison : son allure, teinte et halo glacé
	NS:CompanionUpdateVisibility()
	local f = NS.companionFrame
	local r = f.azSkin.ring
	Check("[WV7] Givre porté hors saison (Azeroth) : teinte argent-bleu et halo glacé", r.azLook == "frost"
		and r.vertex[3] == NS.AZEROTH_RING_TINTS.frost[3] and r.azDesat == true and f.azRingGlow and f.azRingGlow.shown)
	-- saison finie sans cadre d'avant connu : le premier (Ardoise)
	data.unlocked["frame:frost"] = nil
	data.frameStyle, data.frameBeforeGift = "frost", nil
	Check("[WV7] saison finie sans cadre d'avant : Ardoise", NS:CompanionCurrentStyle("frame").id == "slate")
	data.unlocked["frame:copper"] = nil
	data.frameStyle = nil
	Check("[WV7] sans erreur", NoErrors(), select(2, NoErrors()))
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
