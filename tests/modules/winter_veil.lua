-- QuestCompanion 2.14 : le Voile d'hiver.
-- Décor (WinterVeil.lua) : fenêtre de la saison (bornes, nouvel an), réglage
-- auto/on/off et /qc noel, guirlande 3D posée sur le bord doré du cadre du
-- compagnon, flocons et neige qui tombe, guet du mode voyage, décor du carnet
-- (guirlande entre les bords du bois, cadeau et renne autour du titre), boule
-- de neige du filet (scène et « Tout capturer »), cadre givré, teinte de
-- l'anneau par cadre (le cadre choisi l'emporte sur Givre, 2.14.1), Givre
-- offert en saison ; images du client seulement.
-- Compagnons de saison (WinterCompanions.lua) : en saison seulement, sans
-- perdre l'apparence habituelle ; effets, voix, visite surprise, haut fait
-- souvenir, départ en fin de saison.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- ============================================================================================
-- I. Le décor
-- ============================================================================================
do
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

	-- 1. La saison ---------------------------------------------------------------------------------
	do
		Say("-- voile d'hiver : la saison")
		WV.Reset()
		local s = Steps()
		s.ok("fenêtre 15/12 → 2/1", NS.WINTER_VEIL.from.month == 12 and NS.WINTER_VEIL.from.day == 15
			and NS.WINTER_VEIL.to.month == 1 and NS.WINTER_VEIL.to.day == 2)
		s.ok("15 et 31 décembre", NS:WinterVeilSeason(At(2026, 12, 15)) and NS:WinterVeilSeason(At(2026, 12, 31)))
		s.ok("1er et 2 janvier", NS:WinterVeilSeason(At(2027, 1, 1)) and NS:WinterVeilSeason(At(2027, 1, 2)))
		s.ok("14 décembre, 3 janvier, juillet hors saison", not NS:WinterVeilSeason(At(2026, 12, 14))
			and not NS:WinterVeilSeason(At(2027, 1, 3)) and not NS:WinterVeilSeason(JUL1))
		s.check("[WV] saison : du 15 décembre au 2 janvier, nouvel an franchi compris")
		s = Steps()
		s.ok("sans argument en saison", NS:WinterVeilSeason() == true)
		WV.now = JUL1
		s.ok("sans argument en juillet", NS:WinterVeilSeason() == false)
		_G.date = function() error("pas de date") end
		local ok, value = pcall(NS.WinterVeilSeason, NS, DEC20)
		s.ok("date() en panne", ok and value == false)
		_G.date = function() return nil end
		s.ok("date() vide", NS:WinterVeilSeason(DEC20) == false)
		s.check("[WV] saison : maintenant par défaut (time()), date() en panne ou vide = hors saison sans erreur")
		WV.Done()
	end

	-- 2. Le réglage et la commande -------------------------------------------------------------------
	do
		Say("-- voile d'hiver : réglage et /qc noel")
		WV.Reset()
		local s = Steps()
		s.ok("défaut auto", NS:WinterVeilChoice() == "auto")
		s.ok("auto en saison", NS:WinterVeilActive() == true)
		WV.now = JUL1
		s.ok("auto hors saison", NS:WinterVeilActive() == false)
		NS:DB().winterVeil = "on"
		s.ok("toujours en juillet", NS:WinterVeilActive() == true)
		WV.now = DEC20
		NS:DB().winterVeil = "off"
		s.ok("jamais en saison", NS:WinterVeilActive() == false)
		NS:DB().winterVeil = "bidon"
		s.ok("valeur inconnue = auto", NS:WinterVeilChoice() == "auto")
		WV.Reset("sobre", "on")
		s.ok("Sobre jamais, même forcé", NS:WinterVeilActive() == false)
		s.check("[WV] réglage auto / toujours / jamais, valeur inconnue = auto, jamais en style Sobre")

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
		local choices = row and row.choices() or {}
		s = Steps()
		s.ok("sous le style", row and styleIndex and row.index == styleIndex + 1 and row.kind == "action"
			and NS.L.OPT_WINTER_VEIL == "Décor du Voile d'hiver")
		s.ok("trois choix", #choices == 3 and choices[1].value == "auto" and choices[1].hint == "du 15 décembre au 2 janvier"
			and choices[2].label == "Toujours" and choices[3].label == "Jamais")
		if row then row.choose("off") end
		s.ok("choisir", NS:DB().winterVeil == "off" and row.current() == "off" and row.tooltip() == nil)
		s.check("[WV] réglage « Décor du Voile d'hiver » sous le style, trois choix qui s'appliquent")

		s = Steps()
		for _, case in ipairs({ { "on", "on" }, { "jamais", "off" }, { "toujours", "on" }, { "auto", "auto" } }) do
			NS.EXTRA_COMMANDS["noel"](NS, case[1])
			s.ok("/qc noel " .. case[1], NS:DB().winterVeil == case[2])
		end
		s.ok("mot inconnu", NS:WinterVeilCommand("bidon") == nil and NS:DB().winterVeil == "auto")
		s.ok("sans mot", NS:WinterVeilCommand("") == nil)
		s.check("[WV] /qc noel on / jamais / toujours / auto ; mot inconnu ou absent : rien ne change")
		local strings, parity = NS.WINTER_VEIL_STRINGS, {}
		for k in pairs(strings and strings.fr or {}) do if not strings.en[k] then parity[#parity + 1] = k end end
		for k in pairs(strings and strings.en or {}) do if not strings.fr[k] then parity[#parity + 1] = k end end
		Check("[WV] chaînes FR/EN au complet", strings ~= nil and #parity == 0, table.concat(parity, ", "))
		WV.Done()
	end

	-- 3. Le cadre du compagnon -------------------------------------------------------------------------
	do
		Say("-- voile d'hiver : cadre du compagnon")
		WV.Reset(nil, "on")
		NS:CompanionUpdateVisibility()
		local frame = NS.companionFrame
		local d = frame and frame.wvDecor
		local lights = d and d.lights
		local C = NS.WINTER_VEIL_COMPANION
		local box = NS.WinterVeilLightsBox()
		local gift = false
		for _, child in ipairs(d and d.mockChildren or {}) do if child.texture == 133202 then gift = true end end
		Check("[WV] compagnon Azeroth : décor montré sans erreur, guirlande 3D sans souris accrochée au haut du cadre, "
			.. "entre l'anneau et le calque des effets, pas de cadeau", d and Shown(d) and frame.uiStyle == "azeroth" and NoErrors()
			and lights and Shown(lights) and lights.mouseEnabled == false and lights.kind == "PlayerModel"
			and lights.lastPoint.relTo == frame and lights.lastPoint.relPoint == "TOP"
			and lights:GetFrameLevel() > frame.azSkin:GetFrameLevel() and lights:GetFrameLevel() < frame:GetFrameLevel() + 8
			and not gift, select(2, NoErrors()))
		-- 2.14.1 : la guirlande posée sur le bord doré du haut (réglée en jeu)
		local G = NS.WINTER_VEIL_RING_GOLD
		local swags = d.swags or {}
		local s = Steps()
		s.ok("un seul brin, d.lights", #swags == 1 and C.swags == 1 and d.lights == swags[1])
		s.ok("centré sur le cadre", swags[1] and swags[1].lastPoint.x == 0 and math.abs(box.left + box.right) < 1e-6)
		s.ok("plus étroit que l'or", box.w > 0 and box.w < G.w, string.format("%.1f", box.w))
		s.ok("milieu du fil dans la moitié haute de l'or", box.mid <= G.top and box.mid >= (G.top + G.inner) / 2,
			string.format("%.1f (%d..%d)", box.mid, G.inner, G.top))
		s.ok("bouts au-dessus de l'or, bulbes juste dans l'ouverture", box.wire > G.top and box.bottom < G.inner
			and box.bottom >= G.inner - 5, string.format("%.1f / %.1f", box.wire, box.bottom))
		s.check("[WV] guirlande sur le bord doré : un brin centré, plus étroit que l'or, posé sur sa moitié haute")
		-- le client charge le modèle : SetModel(199600), caméra déduite de la taille de bulbe
		for _, model in ipairs(d.swags) do
			model.SetModel = function(m, id) m.loaded = id end
			model.SetCamDistanceScale = function(m, v) m.cam = v end
			model.wvModel = nil
		end
		NS:WinterVeilCompanion()
		Check("[WV] guirlande : modèle 199600 chargé, caméra déduite du bulbe, cadre assez large pour elle (≥ fit × h)",
			lights.loaded == 199600 and math.abs(lights.cam - NS.WinterVeilLightsBox().cam) < 1e-9
			and math.abs(box.cam - C.h * C.bulbH / C.bulb) < 1e-9 and box.cam > 1
			and lights:GetWidth() == box.frameW and box.frameW >= C.fit * C.h - 0.5 and box.frameW >= box.swag)
		-- le réglage en jeu (/qc noel cadre <bulbe> <x> <y> <brins> <cap>)
		local printed = {}
		local print0 = NS.Print
		NS.Print = function(_, text) printed[#printed + 1] = text end
		local DEF = NS.WINTER_VEIL_COMPANION_DEFAULT
		s = Steps()
		NS:WinterVeilCommand("cadre 10 -3 1 3 0.2")
		local tuned = NS.WinterVeilLightsBox()
		s.ok("valeurs posées et réappliquées", C.bulb == 10 and C.x == -3 and C.y == 1 and C.swags == 3 and C.facing == 0.2
			and #d.swags == 3 and Shown(d.swags[3]) and math.abs(d.swags[1].lastPoint.x - tuned.centers[1]) < 1e-6
			and d.swags[1].lastPoint.y == 1 and math.abs(lights.cam - tuned.cam) < 1e-9 and printed[1] ~= nil)
		NS:WinterVeilCommand("cadre - - - 1")
		s.ok("« - » garde, un brin de moins caché", C.bulb == 10 and C.swags == 1 and Shown(d.swags[1]) and not Shown(d.swags[2]))
		NS:WinterVeilCommand("frame default")
		s.ok("valeurs livrées", C.bulb == DEF.bulb and C.swags == DEF.swags and C.x == DEF.x and C.y == DEF.y
			and d.swags[1].lastPoint.y == DEF.y and not Shown(d.swags[2]) and not Shown(d.swags[3]))
		printed = {}
		NS:WinterVeilCommand("cadre")
		s.ok("sans valeur : affichées", #printed == 1 and C.bulb == DEF.bulb)
		NS.Print = print0
		s.check("[WV] /qc noel cadre : réglage en jeu appliqué tout de suite, « - » garde, default rend les valeurs livrées")
		-- bêta 6 : quatre flocons fixes aux coins, bien visibles
		local corners, visible = {}, true
		for index, tex in ipairs(d.flakes) do
			local spec = C.flakes[index]
			if tex.texture ~= ART.flake.file or tex.alpha < 0.85 or not Shown(tex) or tex.lastPoint.relTo ~= frame
				or tex.lastPoint.x ~= spec.x then visible = false end
			corners[(spec.x < 0 and "G" or "D") .. (spec.y > -40 and "H" or "B")] = true
		end
		Check("[WV] quatre flocons fixes aux quatre coins du cadre, presque opaques", #d.flakes == 4 and visible
			and corners.GH and corners.DH and corners.GB and corners.DB)
		-- bêta 5 : mode voyage (interface cachée) : l'habit ne se voit plus, les
		-- modèles 3D si : guirlande et flocons se cachent avec l'habit
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
		s = Steps()
		s.ok("habit visible", DecorOn() and NS:WinterVeilWatch() == false and d.bare == false)
		UIParent:SetAlpha(0)
		s.ok("opacité 0 : nu", NS:WinterVeilCompanionBare(frame) == true)
		s.ok("le guet cache, décor gardé", NS:WinterVeilWatch() == true and DecorOff() and Shown(d) and d.bare == true)
		s.ok("rien refait sans changement", NS:WinterVeilWatch() == false and DecorOff())
		NS:WinterVeilCompanion()
		s.ok("rafraîchissement ne remontre pas", DecorOff())
		UIParent:SetAlpha(1)
		s.ok("interface revenue", NS:WinterVeilWatch() == true and DecorOn())
		frame.azSkin.GetEffectiveAlpha = function() return NS.COMPANION_COMBAT_ALPHA end
		s.ok("combat estompé n'est pas nu", NS:WinterVeilWatch() == false and DecorOn())
		frame.azSkin.GetEffectiveAlpha = function() return 0 end
		s.ok("GetEffectiveAlpha 0", NS:WinterVeilWatch() == true and DecorOff())
		frame.azSkin.GetEffectiveAlpha = nil
		NS:WinterVeilWatch()
		frame.azSkin:Hide()
		s.ok("habit caché", NS:WinterVeilWatch() == true and DecorOff())
		frame.azSkin:Show()
		s.ok("habit remontré", NS:WinterVeilWatch() == true and DecorOn())
		local everyOk = false
		local count, order = NS.ClockJobs()
		for index = 1, count do if order[index] == "noel:cadre" then everyOk = true end end
		s.ok("guet sur l'horloge (noel:cadre)", everyOk)
		s.check("[WV] mode voyage : guirlande et flocons cachés avec l'habit (opacité, habit caché), revenus avec lui, "
			.. "pas pour l'estompe du combat")
		s = Steps()
		NS:SetWinterVeil("off")
		s.ok("jamais : caché sans /reload", not Shown(d) and not Shown(lights))
		NS:SetWinterVeil("on")
		s.ok("toujours : revenu", Shown(d) and Shown(lights))
		NS:SetUIStyle("sobre")
		s.ok("Sobre : caché", not Shown(d) and frame.uiStyle == "sobre")
		NS:SetUIStyle("azeroth")
		s.ok("Azeroth : revenu", Shown(d))
		NS:SetWinterVeil("auto")
		WV.now = JUL1
		NS:CompanionUpdateVisibility()
		s.ok("auto hors saison : caché", not Shown(d))
		WV.now = DEC20
		NS:CompanionUpdateVisibility()
		s.ok("la saison commence : revenu", Shown(d))
		s.check("[WV] décor du compagnon : suit le réglage, le style et la saison à chaud")
		WV.Done()
	end

	-- 4. Le carnet ---------------------------------------------------------------------------------------
	do
		Say("-- voile d'hiver : le carnet")
		WV.Reset(nil, "on")
		local f = NS:ToggleJournal(true)
		local d = f and f.wvDecor
		local J = NS.WINTER_VEIL_JOURNAL
		local ok, errs = NoErrors()
		-- bêta 5 : une seule bande, d'un bord intérieur du bois à l'autre, par-dessus le joint
		local min, max, total, good, shown = math.huge, -math.huge, 0, d and #d.lights > 0, 0
		local xs = {}
		for _, tex in ipairs(d and d.lights or {}) do
			if Shown(tex) then
				shown = shown + 1
				total = total + tex:GetWidth()
				min = math.min(min, tex.lastPoint.x)
				max = math.max(max, tex.lastPoint.x + tex:GetWidth())
				xs[#xs + 1] = { x = tex.lastPoint.x, w = tex:GetWidth() }
				if tex.texture ~= 235484 or tex:GetHeight() ~= J.lightsH or tex.lastPoint.y ~= -LAY.band
					or tex.lastPoint.relTo ~= f or tex:GetParent() ~= d then good = false end
			end
		end
		table.sort(xs, function(a, b) return a.x < b.x end)
		local continuous = #xs > 0
		for index = 2, #xs do if math.abs(xs[index].x - (xs[index - 1].x + xs[index - 1].w)) > 0.01 then continuous = false end end
		local W = f:GetWidth()
		local jointX = LAY.wood + LAY.nav + LAY.gap / 2
		local s = Steps()
		s.ok("décor montré sans erreur", f and f.azeroth and d and Shown(d) and ok, errs)
		s.ok("bande 235484 pendue sous la barre, au-dessus du décor", good and shown == #d.lights
			and d:GetFrameLevel() > f.azOver:GetFrameLevel())
		s.ok("continue, sans trou", continuous and math.abs(total - (max - min)) < 0.01)
		s.ok("dans le bois, marges égales, par-dessus le joint", min >= LAY.wood and max <= W - LAY.wood
			and math.abs((min - LAY.wood) - ((W - LAY.wood) - max)) < 0.01 and min < jointX - 20 and max > jointX + 20,
			string.format("%.1f..%.1f / %d", min, max, W))
		local before = #d.lights
		NS:WinterVeilJournal(f)
		s.ok("rafraîchie : mêmes tuiles", #d.lights == before and d.lightsCount == before)
		s.check("[WV] carnet Azeroth : une guirlande continue entre les bords intérieurs du bois, par-dessus le joint")
		local flakesOk = #d.flakes >= 3 and #d.flakes <= 4
		for _, tex in ipairs(d.flakes) do
			if tex.texture ~= 236121 or tex.alpha > 0.45 or tex.drawLayer ~= "BORDER" or not Shown(tex)
				or tex.lastPoint.y + tex.wvSpec.size / 2 > -J.lightsH then flakesOk = false end
		end
		Check("[WV] carnet : flocons discrets sous la bande et sous les textes, décor sans souris, intitulé « CARNET » caché",
			flakesOk and d.mouseEnabled == false and not f.navGroup:IsShown())
		local title = f.azPlate.title
		local half = title:GetStringWidth() / 2
		local size = J.iconSize
		Check("[WV] cadeau (133202) et renne (236707) autour du titre, sans le toucher", Shown(d.present) and Shown(d.reindeer)
			and d.present.texture == 133202 and d.reindeer.texture == 236707
			and d.present.lastPoint.relTo == title and -d.present.lastPoint.x - size / 2 >= half
			and d.reindeer.lastPoint.x - size / 2 >= half, tostring(d.present.lastPoint.x) .. " / " .. tostring(half))
		s = Steps()
		NS:SetWinterVeil("off")
		s.ok("jamais : caché tout de suite", not Shown(d) and not Shown(d.flakes[1]) and not Shown(d.lights[1])
			and not Shown(d.lights[#d.lights]))
		s.ok("jamais : « CARNET » revient", f.navGroup:IsShown())
		NS:SetWinterVeil("on")
		s.ok("toujours : revenu", Shown(d) and Shown(d.flakes[1]) and Shown(d.lights[1]))
		NS:DB().winterVeil = "auto"
		WV.now = JUL1
		NS:RefreshJournal()
		s.ok("auto hors saison : caché", not Shown(d))
		WV.Done()
		WV.Reset("sobre", "on")
		local sobre = NS:ToggleJournal(true)
		s.ok("Sobre : aucun décor", sobre and not sobre.azeroth and sobre.wvDecor == nil and NoErrors())
		s.check("[WV] décor du carnet : suit le réglage et la saison, jamais en Sobre")
		WV.Done()
	end

	-- 5. La boule de neige ------------------------------------------------------------------------------
	do
		Say("-- voile d'hiver : la boule de neige")
		WV.Reset(nil, "on")
		local NET = "Interface\\Icons\\INV_Misc_Net_01"
		local button = NS:EnsureCaptureNet()
		local s = Steps()
		s.ok("boule de neige", button.icon.texture == 132387)
		NS:SetWinterVeil("off")
		s.ok("hors décor : le filet", button.icon.texture == NET, button.icon.texture)
		NS:SetWinterVeil("on")
		s.ok("revenue", button.icon.texture == 132387)
		NS:SetUIStyle("sobre")
		s.ok("Sobre : le filet", button.icon.texture == NET)
		NS:SetUIStyle("azeroth")
		local glyph = UIParent:CreateTexture(nil, "ARTWORK")
		NS.CapturePaintNetGlyph(glyph)
		s.ok("glyphe des bandeaux", glyph.texture == 132387)
		s.check("[WV] bouton du filet et glyphe des bandeaux : boule de neige pendant le décor, filet sinon, sans /reload")

		-- la scène : la boule vole, puis éclate en flocons ; filet et paquet cachés
		-- (un client qui sait masquer, pour voir la boule arrondie)
		local start = Mock.now
		local mockCreateFrame = _G.CreateFrame
		_G.CreateFrame = function(...)
			local made = mockCreateFrame(...)
			function made:CreateMaskTexture()
				local mask = self:CreateTexture(nil, "ARTWORK")
				function mask:SetTexture(file, h, v) self.texture, self.wrap = file, { h, v } end
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
		local S, B = NS.WINTER_VEIL_SNOWBALL, ART.ball
		s = Steps()
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME * 0.1)
		local ball = stage and stage.wvBall
		local early = ball and ball:GetWidth()
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME * 0.9)
		s.ok("boule en vol, ni paquet ni filet", ball and Shown(ball) and ball.texture == 132387 and not Shown(stage.bundle)
			and not Shown(stage.net) and not Shown(stage.netShadow))
		local mask = ball and ball.masks and ball.masks[1]
		s.ok("découpée autour de la boule, carrée", ball.texCoord[1] == B.c[1] and ball.texCoord[4] == B.c[4]
			and math.abs((B.c[2] - B.c[1]) - (B.c[4] - B.c[3])) < 1e-9)
		s.ok("arrondie par le masque rond du client", mask ~= nil and mask.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
			and mask.allPoints == ball)
		local trail = 0
		for _, tex in ipairs(stage.wvTrail) do if Shown(tex) and tex.texture == 236121 then trail = trail + 1 end end
		s.ok("rapetisse, tourne un peu, traîne de flocons", early > ball:GetWidth() and ball.rotation ~= nil and trail == S.trail)
		s.ok("pied « vole »", stage.footer:GetText() == NS.L.WINTER_VEIL_STAGE_FLY)
		s.check("[WV] scène : la boule de neige vole (découpée, arrondie, traîne), sans paquet ni filet")
		s = Steps()
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME * 0.999)
		local hit = ball.lastPoint
		s.ok("finit sur la créature", stage.chrome == "card" and hit.relTo == stage.scene and math.abs(hit.x) < 2 and math.abs(hit.y) < 2,
			hit.x .. "," .. hit.y)
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + S.burst * 0.1)
		local puff = stage.wvPuff
		local trailGone = true
		for _, tex in ipairs(stage.wvTrail) do if Shown(tex) then trailGone = false end end
		s.ok("pied « remue »", stage.footer:GetText() == NS.L.WINTER_VEIL_STAGE_SHAKE)
		s.ok("bouffée de neige qui grandit, traîne partie", Shown(puff) and puff.blendMode == "ADD" and puff.masks ~= nil
			and puff:GetWidth() > S.size * S.scaleTo and trailGone)
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + S.burst / 2)
		local flakes = stage.wvFlakes
		local burst = #flakes == S.flakes
		for _, tex in ipairs(flakes) do if not Shown(tex) or tex.texture ~= 236121 or tex.alpha >= 0.9 then burst = false end end
		s.ok("éclate en flocons, filet caché", burst and not Shown(stage.wvBall) and not Shown(stage.net))
		NS:CaptureStageUpdate(start + NS.CAPTURE_THROW_TIME + S.burst + 0.5)
		local gone = true
		for _, tex in ipairs(flakes) do if Shown(tex) then gone = false end end
		s.ok("puis tout disparaît", gone and not Shown(stage.wvPuff))
		s.check("[WV] scène : la boule touche la créature, éclate en flocons qui s'effacent")
		NS:CaptureHideStage()
		NS:SetWinterVeil("off")
		stage = NS:CaptureShowStage({ target = { name = "Raptor", class = "normal", npcID = 7100 }, start = Mock.now, done = 0 })
		NS:CaptureStageUpdate(Mock.now + NS.CAPTURE_THROW_TIME * 0.9)
		local errOk, errs = NoErrors()
		Check("[WV] scène hors décor : paquet et filet, pas de boule ; aucune erreur de capture", Shown(stage.bundle)
			and Shown(stage.net) and not Shown(stage.wvBall) and errOk, errs)
		NS:CaptureHideStage()
		WV.Done()
	end

	-- 5 bis. « Tout capturer » : une boule de neige par case ---------------------------------------------
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
		local s = Steps()
		NS:CaptureBatchUpdate(batch.startedAt + first.dropAt + drape / 2)
		s.ok("boule qui tombe, découpée, pas de filet", Shown(first.tile.wvBall) and first.tile.wvBall.texture == 132387
			and first.tile.wvBall.texCoord[1] == ART.ball.c[1] and NetsHidden(batch))
		NS:CaptureBatchUpdate(batch.startedAt + first.dropAt + drape + NS.WINTER_VEIL_SNOWBALL.burst / 2)
		local burst = #first.tile.wvFlakes == NS.WINTER_VEIL_SNOWBALL.tileFlakes
		for _, tex in ipairs(first.tile.wvFlakes) do if not Shown(tex) or tex.texture ~= 236121 then burst = false end end
		s.ok("éclate en flocons, filet caché", burst and not Shown(first.tile.wvBall) and NetsHidden(batch))
		NS:CaptureBatchStop(true)
		local quiet = true
		for _, card in ipairs(batch.cards) do
			if Shown(card.tile.wvBall) then quiet = false end
			for _, tex in ipairs(card.tile.wvFlakes or {}) do if Shown(tex) then quiet = false end end
		end
		s.ok("arrêtée : ni filet ni neige", batch.done and quiet and NetsHidden(batch))
		local ok, errs = NoErrors()
		s.ok("sans erreur", ok, errs)
		s.check("[WV] « Tout capturer » : une boule de neige par case, qui éclate ; jamais de filet pendant le décor")
		if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
		NS.captureBatch = nil
		NS:SetWinterVeil("off")
		batch = Batch()
		first = batch.cards[1]
		NS:CaptureBatchUpdate(batch.startedAt + first.dropAt + drape / 2)
		local falls = Shown(first.tile.net) and not Shown(first.tile.wvBall)
		NS:CaptureBatchStop(true)
		Check("[WV] « Tout capturer » hors décor : le filet tombe, déchiré sur l'échappée", falls and Shown(batch.cards[2].tile.net))
		if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
		NS.captureBatch = nil
		NS.captureBatchFrame, NS.captureBatchFrames = nil, nil
		WV.Done()
	end

	-- 6. La neige qui tombe et le cadre givré -----------------------------------------------------------------
	do
		Say("-- voile d'hiver : neige qui tombe, cadre givré")
		WV.Reset(nil, "on")
		-- le client sait boucler un groupe d'animations (SetLooping)
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
		local anims, delays, distinct = true, {}, 0
		for index, tex in ipairs(d and d.snow or {}) do
			local g, spec = tex.wvAnim, S[index]
			if not (g and g.looping == "REPEAT" and tex.texture == ART.flake.file and tex.alpha == 0
				and tex.lastPoint.relTo == frame and g.fall.kind == "Translation" and g.fall.offset[2] < 0
				and g.fadeIn.kind == "Alpha" and g.fadeIn.from == 0 and g.fadeOut.kind == "Alpha" and g.fadeOut.to == 0) then
				anims = false
			end
			if not delays[spec.delay] then delays[spec.delay] = true; distinct = distinct + 1 end
		end
		local plays = d and d.snow[1] and d.snow[1].wvAnim.plays
		NS:WinterVeilCompanion()
		Check("[WV] neige : quelques flocons qui tombent en boucle (animations du client, sans OnUpdate), décalés, "
			.. "transparents au repos, pas relancés au rafraîchissement", d and #d.snow >= 4 and #d.snow <= 6 and Snowing()
			and NoErrors() and anims and distinct == #d.snow and not (d.scripts and d.scripts.OnUpdate)
			and not (d.hooks and d.hooks.OnUpdate) and d.snow[1].wvAnim.plays == plays, select(2, NoErrors()))
		local s = Steps()
		_G.InCombatLockdown = function() return true end
		s.ok("combat estompé : s'arrête, flocons fixes et guirlande gardés", NS:WinterVeilWatch() == true and SnowStopped()
			and Shown(d.flakes[1]) and Shown(d.swags[1]))
		s.ok("rien refait", NS:WinterVeilWatch() == false and SnowStopped())
		NS:DB().companionCombatFade = false
		s.ok("combat sans estompe : tombe", NS:WinterVeilWatch() == true and Snowing())
		NS:DB().companionCombatFade = nil
		NS:WinterVeilWatch()
		_G.InCombatLockdown = function() return false end
		NS.companionFighting = nil
		s.ok("fin du combat : reprend", NS:WinterVeilWatch() == true and Snowing())
		UIParent:SetAlpha(0)
		s.ok("mode voyage : cachée", NS:WinterVeilWatch() == true and SnowStopped())
		UIParent:SetAlpha(1)
		s.ok("interface revenue", NS:WinterVeilWatch() == true and Snowing())
		s.check("[WV] neige : s'arrête quand le compagnon s'estompe en combat ou en mode voyage, reprend ensuite")

		-- le cadre givré (allure Azeroth du cadre Givre, AZEROTH_RING_TINTS.frost)
		local ring = frame.azSkin.ring
		local F = NS.AZEROTH_RING_TINTS.frost
		local glow = frame.azRingGlow
		local function Visible(region)
			local node = region
			while node and node ~= frame do
				if node.shown == false then return false end
				node = node.mockParent
			end
			return region ~= nil and region.shown == true
		end
		local function Gold(tex) return tex.vertex[1] == 1 and tex.vertex[2] == 1 and tex.vertex[3] == 1 and tex.azDesat == false end
		local holder = glow and glow.holder
		local modelLevel = frame.model and frame.model.GetFrameLevel and frame.model:GetFrameLevel()
		Check("[WV] givre (par défaut) : anneau désaturé argent-bleu, halo glacé du client en ADD sur l'habit, sous le modèle",
			NS:WinterVeilFrostOn() == true and ring.vertex and ring.vertex[1] == F[1] and ring.vertex[3] == F[3]
			and ring.azDesat == true and ring.azLook == "frost"
			and glow and holder and Visible(glow) and glow.atlas == "Relic-Frost-TraitGlowRing" and glow.blendMode == "ADD"
			and holder:GetParent() == frame.azSkin and (holder:GetFrameLevel() or 0) < (modelLevel or 99)
			and glow.width > NS.AZEROTH_RING.w, ring.vertex and table.concat(ring.vertex, ","))
		local row, at, decorAt
		for _, page in ipairs(NS.OPTION_PAGES or {}) do
			if page.id == "companionMain" then
				for index, r in ipairs(page.rows) do
					if r.key == "winterVeilFrost" then row, at = r, index end
					if r.key == "winterVeil" then decorAt = index end
				end
			end
		end
		Check("[WV] réglage « Cadre givré (Voile d'hiver) » : case à cocher sous le décor", row and row.kind == "bool"
			and at == decorAt + 1 and NS.L[row.label] == "Cadre givré (Voile d'hiver)" and row.describe() ~= nil)
		-- 2.14.1 : le cadre choisi pendant la saison l'emporte sur Givre
		s = Steps()
		NS:DB().winterVeilFrost = false
		row.onChange()
		local curFrame = NS:CompanionCurrentStyle("frame").id
		s.ok("givre coupé : teinte du cadre choisi, halo caché, décor gardé",
			ring.azLook == (NS.AZEROTH_RING_TINTS[curFrame] and curFrame or nil) and not Visible(glow) and Shown(d) and Snowing())
		NS:CompanionData().unlocked["frame:copper"] = true
		NS:CompanionSetStyle("frame", "copper")
		s.ok("Cuivre choisi : cuivré", ring.azLook == "copper" and ring.vertex[2] == NS.AZEROTH_RING_TINTS.copper[2])
		NS:DB().winterVeilFrost = true
		row.onChange()
		s.ok("choisi pendant la saison : l'emporte sur Givre", ring.azLook == "copper" and NS:CompanionData().winterFrameChoice == true)
		NS:CompanionData().winterFrameChoice = nil
		row.onChange()
		s.ok("sans choix pendant la saison : Givre", ring.azLook == "frost" and Visible(glow)
			and NS:CompanionCurrentStyle("frame").id == "copper")
		s.check("[WV] cadre choisi pendant la saison : il l'emporte sur l'allure Givre ; sans choix, Givre")
		s = Steps()
		frame.azSkin:Hide()
		NS:WinterVeilWatch()
		s.ok("habit caché : halo caché", not Visible(glow))
		frame.azSkin:Show()
		NS:WinterVeilWatch()
		s.ok("habit revenu : halo revenu", Visible(glow))
		NS:SetUIStyle("sobre")
		s.ok("Sobre : anneau à l'or, halo et neige cachés", Gold(ring) and not Visible(glow) and SnowStopped())
		NS:SetUIStyle("azeroth")
		s.ok("retour en Azeroth", ring.vertex[1] == F[1] and Visible(glow) and Snowing())
		NS:SetWinterVeil("off")
		s.ok("jamais : teinte du cadre choisi", ring.azLook == "copper" and not Visible(glow) and SnowStopped())
		NS:SetWinterVeil("auto")
		WV.now = JUL1
		NS:CompanionUpdateVisibility()
		s.ok("hors saison : teinte du cadre choisi", ring.azLook == "copper" and not Visible(glow) and SnowStopped())
		s.check("[WV] givre et neige : cachés avec l'habit, en Sobre, hors décor ; l'anneau reprend la teinte du cadre choisi")
		NS:CompanionData().unlocked["frame:copper"] = nil
		NS:CompanionData().frameStyle = nil
		WV.Done()

		-- atlas du halo absent : rien posé, sans erreur, la teinte reste
		WV.Reset(nil, "on")
		Mock.InstallAtlas({ ["Relic-Frost-TraitGlowRing"] = true })
		NS:AzerothAtlasOK(true)
		NS:CompanionUpdateVisibility()
		frame = NS.companionFrame
		local skinRing = frame.azSkin and frame.azSkin.ring
		s = Steps()
		s.ok("pas d'anneau Kyrian en repli", frame.azRingGlow == false and #NS.AZEROTH_RING_GLOW.atlases == 1)
		s.ok("anneau givré quand même", skinRing and skinRing.vertex and skinRing.vertex[1] == F[1] and NoErrors())
		NS:SetWinterVeil("off")
		s.ok("hors décor : Ardoise en gris", skinRing and skinRing.azLook == "slate" and NoErrors())
		s.check("[WV] halo de glace absent du client : rien posé, pas de repli, l'anneau givré quand même, sans erreur")
		WV.Done()
	end

	-- 7. Teinte de l'anneau par cadre, Givre offert pendant la saison --------------------------------------
	do
		Say("-- voile d'hiver : teinte de l'anneau par cadre, Givre offert")
		local TINTS = NS.AZEROTH_RING_TINTS
		WV.Reset(nil, "off")
		NS:CompanionUpdateVisibility()
		local frame = NS.companionFrame
		local ring = frame.azSkin.ring
		local data = NS:CompanionData()
		local missing = {}
		for _, def in ipairs(NS.COMPANION_FRAMES) do
			data.unlocked["frame:" .. def.id] = true
			-- 3.0.0 : les cadres de l'Échoppe se débloquent à l'achat (au compte)
			if def.unlock and def.unlock.shop and NS.ShopCosmeticGrant then NS:ShopCosmeticGrant(def.unlock.shop) end
			local set = NS:CompanionSetStyle("frame", def.id)
			local look = TINTS[def.id]
			if not look and def.id:find("^seal_") then look = { def.edge[1], def.edge[2], def.edge[3], desat = true } end
			local r, g, b = 1, 1, 1
			if look and look[1] then r, g, b = look[1], look[2], look[3] end
			if not (set and ring.vertex[1] == r and ring.vertex[2] == g and ring.vertex[3] == b
				and ring.azDesat == ((look and look.desat) and true or false)
				and ring.azLook == (look and def.id or nil)) then
				missing[#missing + 1] = def.id
			end
			data.unlocked["frame:" .. def.id] = nil
		end
		Check("[WV] Azeroth : chaque cadre colore l'anneau (teinte, désaturation), sans erreur", #missing == 0 and NoErrors(),
			table.concat(missing, ",") .. " " .. select(2, NoErrors()))
		local function Desat(id) return TINTS[id] and TINTS[id].desat == true end
		Check("[WV] palette : Ardoise (défaut) en gris (2.14.1), Insigne à l'or, argent/givre/runique/gangrené/chêne désaturés, "
			.. "teintes de Givre, Runique, Gangrené, Cuivre ; halos d'Étincelant (doré) et de Givre (glacé)",
			TINTS.slate and TINTS.slate.desat and TINTS.trainer == nil and NS.COMPANION_FRAMES[1].id == "slate"
			and Desat("silver") and Desat("frost") and Desat("rune") and Desat("fel") and Desat("oak")
			and not Desat("copper") and not Desat("gilded")
			and TINTS.frost[3] > TINTS.frost[1] and TINTS.rune[3] > TINTS.rune[2] and TINTS.fel[2] > TINTS.fel[1]
			and TINTS.fel[2] > TINTS.fel[3] and TINTS.copper[1] > TINTS.copper[2] and TINTS.copper[2] > TINTS.copper[3]
			and TINTS.sparkle.glow and TINTS.frost.glow and TINTS.sparkle.glow[1] > TINTS.sparkle.glow[3]
			and TINTS.frost.glow[3] > TINTS.frost.glow[1])
		local s = Steps()
		data.unlocked["frame:sparkle"] = true
		NS:CompanionSetStyle("frame", "sparkle")
		local glow = frame.azRingGlow
		s.ok("Étincelant : or clair et halo doré", ring.vertex[2] == TINTS.sparkle[2] and ring.azDesat == false
			and glow and glow.shown and glow.vertex[1] == TINTS.sparkle.glow[1])
		NS:CompanionSetStyle("frame", "slate")
		s.ok("Ardoise : gris, halo caché", ring.vertex[1] == TINTS.slate[1] and ring.azDesat == true and not glow.shown)
		data.unlocked["frame:sparkle"] = nil
		data.unlocked["frame:fel"] = true
		NS:CompanionSetStyle("frame", "fel")
		local vine = { SetVertexColor = function(t, r, g, b, a) t.vertex = { r, g, b, a } end }
		local journal = { evo = { azVine = vine } }
		s.ok("portrait de la page Créature : Gangrené", NS:CarnetPaintRing(journal) == "fel" and vine.vertex[2] == TINTS.fel[2]
			and vine.azDesat == true)
		NS:CompanionSetStyle("frame", "slate")
		s.ok("portrait de la page Créature : Ardoise", NS:CarnetPaintRing(journal) == "slate" and vine.vertex[1] == TINTS.slate[1])
		data.unlocked["frame:fel"] = nil
		data.unlocked["frame:rune"] = true
		NS:CompanionSetStyle("frame", "rune")
		NS:SetUIStyle("sobre")
		s.ok("Sobre inchangé : bordure du client, anneau à l'or", frame.frameStyle == "rune" and frame.styleBorder
			and frame.styleBorder.shown and ring.vertex[1] == 1 and ring.azDesat == false and ring.azLook == nil)
		NS:SetUIStyle("azeroth")
		s.check("[WV] halo d'Étincelant, Ardoise en gris, même teinte au portrait du carnet ; Sobre inchangé")
		data.unlocked["frame:rune"] = nil
		data.frameStyle = nil
		WV.Done()

		-- Givre offert pendant la saison, repris après
		local frost
		for _, def in ipairs(NS.COMPANION_FRAMES) do if def.id == "frost" then frost = def end end
		WV.Reset(nil, "auto", JUL1)
		data = NS:CompanionData()
		data.unlocked["frame:frost"] = nil
		s = Steps()
		s.ok("hors saison : verrouillé", not NS:CompanionIsUnlocked("frame", frost) and not NS:CompanionSetStyle("frame", "frost"))
		WV.now = DEC20
		s.ok("en saison : offert", NS:CompanionIsUnlocked("frame", frost) and not NS:WinterVeilGiftEarned())
		local entry
		for _, e in ipairs(NS:CompanionChoices("frame")) do if e.value == "frost" then entry = e end end
		s.ok("liste : indice « Voile d'hiver »", entry and not entry.disabled and entry.hint == "Voile d'hiver")
		data.unlocked["frame:copper"] = true
		NS:CompanionSetStyle("frame", "copper")
		NS:CompanionSetStyle("frame", "frost")
		s.ok("choisi : cadre d'avant gardé", NS:CompanionCurrentStyle("frame").id == "frost" and data.frameBeforeGift == "copper")
		WV.now = At(2027, 1, 3)
		s.ok("saison finie : retour au cadre d'avant", NS:CompanionCurrentStyle("frame").id == "copper"
			and data.frameStyle == "copper" and data.frameBeforeGift == nil)
		NS:DB().winterVeil = "on"
		s.ok("/qc noel on : offert hors saison", NS:CompanionIsUnlocked("frame", frost))
		NS:DB().winterVeil = "auto"
		s.check("[WV] Givre offert pendant la saison (indice « Voile d'hiver »), le cadre d'avant rendu à la fin")
		s = Steps()
		WV.now = DEC20
		NS:CompanionSetStyle("frame", "frost")
		data.unlocked["frame:frost"] = true
		WV.now = JUL1
		s.ok("gagné : gardé hors saison", NS:CompanionIsUnlocked("frame", frost) and NS:WinterVeilGiftEarned()
			and NS:CompanionCurrentStyle("frame").id == "frost" and data.frameBeforeGift == nil)
		NS:CompanionUpdateVisibility()
		local f = NS.companionFrame
		local r = f.azSkin.ring
		s.ok("porté hors saison : son allure", r.azLook == "frost" and r.vertex[3] == TINTS.frost[3] and f.azRingGlow
			and f.azRingGlow.shown)
		data.unlocked["frame:frost"] = nil
		data.frameStyle, data.frameBeforeGift = "frost", nil
		s.ok("fin sans cadre d'avant : Ardoise", NS:CompanionCurrentStyle("frame").id == "slate")
		s.ok("sans erreur", NoErrors(), select(2, NoErrors()))
		s.check("[WV] Givre gagné : gardé hors saison avec son allure ; sans cadre d'avant connu, Ardoise")
		data.unlocked["frame:copper"] = nil
		data.frameStyle = nil
		WV.Done()
	end

	-- 8. Images du client seulement ----------------------------------------------------------------------
	do
		local numbers = true
		for _, spec in pairs(NS.WINTER_VEIL_ART) do if type(spec.file) ~= "number" then numbers = false end end
		Check("[WV] images du décor : FileDataID du client (guirlande, flocon, cadeau, renne, boule), rien de livré",
			numbers and type(NS.WINTER_VEIL_COMPANION.model) == "number" and ART.lights.file == 235484
			and ART.flake.file == 236121 and ART.present.file == 133202 and ART.reindeer.file == 236707
			and ART.snowball.file == 132387)
	end
end

-- ============================================================================================
-- II. Les compagnons de saison (la saison remplacée par un interrupteur du test)
-- ============================================================================================
do
	local W = { random = math.random, season = NS.WinterVeilSeason, share = NS.WINTER_VOICE_SHARE,
		inCombat = rawget(_G, "InCombatLockdown"), affecting = rawget(_G, "UnitAffectingCombat"),
		date = rawget(_G, "date"), gameTime = rawget(_G, "GetGameTime"), instance = rawget(_G, "IsInInstance") }
	local seed = 2140
	local function Random(a, b)
		seed = (seed * 1103515245 + 12345) % 2147483648
		local r = seed / 2147483648
		if not a then return r end
		if not b then return math.floor(r * a) + 1 end
		return a + math.floor(r * (b - a + 1))
	end
	local function Starts(key, prefix)
		if type(key) ~= "string" then return false end
		local tail = key:sub(#prefix + 1)
		return key:sub(1, #prefix) == prefix and (tail == "" or tail:match("^_%d+$") ~= nil)
	end
	local function Logged(text)
		for _, line in ipairs(Mock.output) do if line:find(text, 1, true) then return true end end
		return false
	end

	function W.Free()
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
		NS.companionBubbleText, NS.companionBubbleLine = nil, nil
		if NS.companionRT then NS.companionRT.cool = {}; NS.companionRT.seq = nil end
	end
	function W.Season(on)
		W.on = on
		NS:WinterCompanionsForget()
	end
	function W.Reset(on)
		ResetWorld()
		NS.companionRT, NS.companionSession, NS.companionFighting = nil, nil, nil
		W.Free()
		W.combat, W.day, W.hour, W.inside = false, "2026-12-20", 12, false
		_G.InCombatLockdown = function() return W.combat end
		_G.UnitAffectingCombat = function() return W.combat end
		_G.date = function(fmt) if fmt == "%Y-%m-%d" then return W.day end return W.date and W.date(fmt) or "" end
		_G.GetGameTime = function() return W.hour, 0 end
		_G.IsInInstance = function() return W.inside, W.inside and "party" or "none" end
		NS.WinterVeilSeason = function() return W.on end
		W.Season(on)
		local data = NS:CompanionData()
		data.tutoDone = true
		data.winter = nil
		data.appearance = NS.COMPANION_APPEARANCES[1].id
		data.effects = nil
		NS:DB().companionChatter = 3
		NS:DB().companionWinterVisit = nil
		NS:DB().companionShow = nil
		NS.winterVisited, NS.winterVisitAt, NS.winterTemp = nil, nil, nil
		if NS.WinterVisitHide then NS:WinterVisitHide() end
		NS.WINTER_VOICE_SHARE = 1
		NS:CompanionUpdateVisibility()
		math.random = Random
	end
	function W.Done()
		math.random = W.random
		NS.WinterVeilSeason, NS.WINTER_VOICE_SHARE = W.season, W.share
		_G.InCombatLockdown, _G.UnitAffectingCombat = W.inCombat, W.affecting
		_G.date, _G.GetGameTime, _G.IsInInstance = W.date, W.gameTime, W.instance
		local data = NS:CompanionData()
		data.winter, data.effects = nil, nil
		NS:WinterCompanionsForget()
		NS.winterVisited, NS.winterVisitAt, NS.winterTemp = nil, nil, nil
		if NS.WinterVisitHide then NS:WinterVisitHide() end
		W.Free()
		ResetWorld()
	end
	-- effets actifs tout de suite (le délai de 2 minutes est passé)
	function W.Active()
		NS:CompanionEffectsSync()
		NS:CompanionData().effects.since = 0
		NS.effectCache = nil
	end
	local function Ids(list)
		local ids = {}
		for _, def in ipairs(list) do ids[#ids + 1] = def.id end
		return ids
	end
	local function Has(list, id)
		for _, def in ipairs(list) do if def.id == id or def.value == id then return true end end
		return false
	end

	-- 1. Les textes ---------------------------------------------------------------------------------
	do
		Say("-- compagnons du Voile d'hiver : les textes")
		local fr, en, POOLS = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en, NS.COMPANION_POOLS
		local function Specs(text)
			local list = {}
			for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
			return table.concat(list, ",")
		end
		local ARGS = { KILL = "%s", CAPTURE_OK = "%s", CAPTURE_FAIL = "%s", SHINY_SPOTTED = "%s", LEVEL = "%s",
			CITY = "%s", DUNGEON = "%s" }
		Check("[NOEL] trois compagnons (PNJ 13444, 15664, 15710), noms FR, répliques validées verbatim",
			#NS.WINTER_COMPANIONS == 3 and NS.WINTER_COMPANIONS[1].npc == 13444 and NS.WINTER_COMPANIONS[2].npc == 15664
			and NS.WINTER_COMPANIONS[3].npc == 15710 and NS.L.WINTER_COMP_gfw == "Grand-père Hiver"
			and NS.L.WINTER_COMP_metzen == "Metzen le renne" and NS.L.WINTER_COMP_snowman == "Petit bonhomme de neige"
			and fr[POOLS.HELLO_V_gfw[1]] == "Ho ho ho ! Tu as été sage cette année ? Les mobs que tu as tués, eux, ne diront rien."
			and fr[POOLS.CAPTURE_OK_V_gfw[1]] == "Encore un pour la hotte !" and fr[POOLS.WINTER_HOT[1]] == "Je… ruisselle.")
		local bad, counts = {}, {}
		for _, def in ipairs(NS.WINTER_COMPANIONS) do
			local total = 0
			for _, situ in ipairs(NS.WINTER_VOICE_SITUATIONS) do
				local keys = POOLS[situ .. "_V_" .. def.seasonal]
				if not keys or #keys < 2 then bad[#bad + 1] = situ .. "_V_" .. def.seasonal .. " (moins de 2)" end
				for _, key in ipairs(keys or {}) do
					total = total + 1
					local f, e = fr[key], en[key]
					local spec = Specs(f)
					if type(f) ~= "string" or f == "" or type(e) ~= "string" or e == "" or spec ~= Specs(e)
						or (spec ~= "" and spec ~= ARGS[situ]) or #f > 110 or #e > 110 then bad[#bad + 1] = key end
				end
			end
			counts[#counts + 1] = def.seasonal .. "=" .. total
			if total < 40 then bad[#bad + 1] = def.seasonal .. " " .. total .. " répliques" end
		end
		Check("[NOEL] chaque voix : ~40 répliques sur toutes les situations, FR/EN non vides, mêmes arguments, courtes",
			#bad == 0, table.concat(bad, ", "))
		Say("   voix : " .. table.concat(counts, ", "))
		local missing = {}
		for _, pool in ipairs({ "WINTER_SACK", "WINTER_HOT", "WINTER_COLD", "WINTER_BYE_gfw", "WINTER_BYE_metzen",
			"WINTER_BYE_snowman", "WINTER_VISIT" }) do
			local keys = POOLS[pool]
			if not keys or #keys == 0 then missing[#missing + 1] = pool end
			for _, key in ipairs(keys or {}) do
				if not (fr[key] and en[key]) or Specs(fr[key]) ~= Specs(en[key]) then missing[#missing + 1] = key end
			end
		end
		for _, key in ipairs({ "EFF_winter_treat", "EFF_winter_sack", "EFF_winter_energy", "EFF_winter_nose", "EFF_winter_pet",
			"EFF_winter_cold", "EFF_SEASON", "EFF_QUIRK", "EFF_SECTION_WINTER" }) do
			if not (NS.EFFECT_STRINGS.fr[key] and NS.EFFECT_STRINGS.en[key]) then missing[#missing + 1] = key end
		end
		for _, key in ipairs({ "WINTER_MSG_BYE", "WINTER_MSG_SACK", "OPT_COMP_WINTER_VISIT", "OPT_COMP_WINTER_VISIT_DESC" }) do
			if NS.L[key] == key or NS.L[key] == nil then missing[#missing + 1] = key end
		end
		Check("[NOEL] hotte, chaud, froid, au revoir, visite, effets, messages : FR et EN", #missing == 0, table.concat(missing, ", "))
	end

	-- 2. En saison seulement ; l'apparence habituelle reste --------------------------------------------
	do
		Say("-- compagnons du Voile d'hiver : le choix")
		W.Reset(false)
		local regular = NS:CompanionData().appearance
		Check("[NOEL] hors saison : absents des apparences et des réglages, choix refusé",
			not Has(NS:CompanionAllAppearances(), "winter:gfw") and not Has(NS:CompanionChoices("app"), "winter:metzen")
			and NS:CompanionSetAppearance("winter:gfw") == nil and NS:CompanionCurrentAppearance().id == regular)
		W.Season(true)
		local ids = Ids(NS:CompanionUnlockedAppearances())
		local s = Steps()
		s.ok("les trois en tête", ids[1] == "winter:gfw" and ids[2] == "winter:metzen" and ids[3] == "winter:snowman",
			table.concat(ids, ","))
		s.ok("dans les réglages", Has(NS:CompanionChoices("app"), "winter:snowman"))
		local def = NS:CompanionSetAppearance("winter:metzen")
		local data = NS:CompanionData()
		s.ok("Metzen porté, habituelle gardée", def and def.seasonal == "metzen"
			and NS:CompanionCurrentAppearance().id == "winter:metzen" and data.appearance == regular and data.winter.pick == "metzen")
		s.ok("son nom", NS:CompanionName() == "Metzen le renne")
		s.ok("bonjour avec sa voix", Starts(NS.companionBubbleLine, "COMP_SAY_HELLO_V_metzen"), NS.companionBubbleLine)
		s.check("[NOEL] en saison : en tête de « Son allure », choisi sans perdre l'apparence habituelle, son nom et sa voix")
		s = Steps()
		NS:CompanionSetAppearance(regular)
		s.ok("habituelle choisie : elle revient", data.winter.pick == nil and NS:CompanionCurrentAppearance().id == regular
			and NS:CompanionName() ~= "Metzen le renne")
		NS:CompanionSetAppearance("winter:snowman")
		local nextDef = NS:CompanionCycleAppearance()
		s.ok("cycle sans écraser l'habituelle", nextDef and data.appearance == regular
			and NS:CompanionCurrentAppearance().id == nextDef.id, nextDef and nextDef.id)
		s.check("[NOEL] retour à l'apparence habituelle et cycle de /qc compagnon : l'habituelle jamais écrasée")
		W.Done()
	end

	-- 3. Effets et particularités ---------------------------------------------------------------------
	do
		Say("-- compagnons du Voile d'hiver : effets")
		W.Reset(true)
		NS:CompanionSetAppearance("winter:metzen")
		W.Active()
		local effects = NS:CompanionEffects()
		local lines = NS:CompanionEffectsText(effects)
		Check("[NOEL] Metzen : énergie et nez qui brille (Saison / Particularité), l'énergie baisse moins vite",
			effects and effects.seasonal == "metzen" and effects.hunt.id == "winter_energy" and effects.comfort.id == "winter_nose"
			and effects.active and not effects.mascot and lines[1]:find("^Saison : ") and lines[2]:find("^Particularité : ")
			and lines[2]:find("nez qui brille", 1, true) and NS:CompanionDecayFactor("energy") < 1
			and NS:CompanionDecayFactor("hunger") == 1, table.concat(lines, " / "))
		W.hour = 12
		local day = NS:CompanionCaptureBonus({ class = "normal", typeKey = "beast" })
		W.hour = 22
		local night = NS:CompanionCaptureBonus({ class = "normal", typeKey = "beast" })
		W.hour = 3
		local late = NS:CompanionCaptureBonus({ class = "normal", typeKey = "beast" })
		local base = NS.CaptureChanceBase and NS:CaptureChanceBase({ class = "normal", level = 11 }) or nil
		local with = NS:CaptureChance({ class = "normal", level = 11 })
		Check("[NOEL] nez qui brille : capture en plus la nuit (heure du jeu) seulement, par l'enveloppe de la chance",
			day == 0 and night > 0 and late == night and base and with > base,
			day .. " / " .. night .. " / " .. late .. " ; " .. tostring(base) .. " -> " .. tostring(with))

		-- Grand-père Hiver : la hotte (une fois par jour)
		W.Reset(true)
		local items, pantry = NS:CaptureData().items, NS:TreatData().pantry
		local function Total()
			local n = 0
			for _, v in pairs(items) do n = n + (tonumber(v) or 0) end
			for _, v in pairs(pantry) do n = n + (tonumber(v) or 0) end
			return n
		end
		local before = Total()
		local s = Steps()
		NS:CompanionSetAppearance("winter:gfw")
		local data = NS:CompanionData()
		s.ok("un cadeau au premier choix du jour", data.winter.sackDay == "2026-12-20" and Total() == before + 1
			and Logged("La hotte de Grand-père Hiver"), before .. " -> " .. Total())
		s.ok("une seule fois par jour", NS:WinterSackCheck() == nil and NS:WinterCompanionsLogin() == nil and Total() == before + 1)
		W.day = "2026-12-21"
		W.Free()
		local label = NS:WinterCompanionsLogin()
		s.ok("le lendemain à la connexion", label and Total() == before + 2 and Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_SACK"),
			NS.companionBubbleLine)
		W.Active()
		local gfw = NS:CompanionEffects()
		s.ok("effets friandise + hotte", gfw.hunt.id == "winter_treat" and gfw.comfort.id == "winter_sack"
			and NS.COMPANION_EFFECTS.winter_treat.kind == "treatZone")
		NS:CompanionSetAppearance("winter:metzen")
		W.day = "2026-12-22"
		s.ok("seulement avec lui", NS:WinterSackCheck() == nil)
		s.check("[NOEL] Grand-père Hiver : la hotte, un cadeau par jour (au choix ou à la connexion), seulement avec lui")

		-- Petit bonhomme de neige : caresse, froid, chaleur
		W.Reset(true)
		NS:CompanionSetAppearance("winter:snowman")
		W.Active()
		local snow = NS:CompanionEffects()
		Mock.world.mapID = 1426
		local cold = { NS:CompanionDecayFactor("hunger"), NS:CompanionDecayFactor("mood") }
		Mock.world.mapID = 1446
		local hot = { NS:CompanionDecayFactor("hunger"), NS:CompanionDecayFactor("mood") }
		Mock.world.mapID = 1429
		local mild = { NS:CompanionDecayFactor("hunger"), NS:CompanionDecayFactor("mood") }
		Check("[NOEL] bonhomme de neige : caresse et froid ; envies plus lentes au froid, il fond au chaud, rien ailleurs",
			snow.hunt.id == "winter_pet" and snow.comfort.id == "winter_cold" and NS.COMPANION_EFFECTS.winter_pet.kind == "pet"
			and cold[1] < 1 and cold[2] < 1 and hot[1] == 1 and hot[2] == NS.WINTER_MELT and mild[1] == 1 and mild[2] == 1
			and NS.WINTER_COLD_MAPS[1452] and NS.WINTER_COLD_MAPS[1416] and NS.WINTER_HOT_MAPS[1413]
			and NS.WINTER_HOT_MAPS[1451] and not NS.WINTER_HOT_MAPS[1426])
		s = Steps()
		W.Free()
		Mock.world.mapID = 1446
		NS:CompanionOnZone(true)
		s.ok("chaleur : « ruisselle »", Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_HOT"), NS.companionBubbleLine)
		W.Free()
		NS:CompanionOnZone(true)
		s.ok("même chaleur : pas redit", NS.companionBubbleLine == nil or not Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_HOT"))
		W.Free()
		Mock.world.mapID = 1452
		NS:CompanionOnZone(true)
		s.ok("froid : il se réjouit", Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_COLD"), NS.companionBubbleLine)
		local mood = NS:CompanionData().needs.mood
		NS:CompanionData().needs.mood = 50
		NS.companionLastPet = nil
		NS:CompanionPet()
		s.ok("caresse : le moral monte plus", NS:CompanionData().needs.mood > 58, NS:CompanionData().needs.mood)
		NS:CompanionData().needs.mood = mood
		s.check("[NOEL] bonhomme de neige : répliques d'entrée au chaud / au froid (pas redites), caresse renforcée")
		W.Done()
	end

	-- 4. Voix -------------------------------------------------------------------------------------------
	do
		Say("-- compagnons du Voile d'hiver : voix")
		W.Reset(true)
		NS:CompanionSetAppearance("winter:gfw")
		local s = Steps()
		for _, case in ipairs({ { "KILL", "COMP_SAY_KILL_V_gfw", { "Gnoll" } }, { "CAPTURE_OK", "COMP_SAY_CAPTURE_OK_V_gfw", { "Loup" } },
			{ "DUNGEON", "COMP_SAY_DUNGEON_V_gfw" }, { "NEED_energy", "COMP_SAY_NEED_V_gfw" }, { "VIEW", "COMP_SAY_VIEW_V_gfw" },
			{ "COMBAT_SUM", "COMP_SAY_COMBAT_V_gfw", { 3 } }, { "LOOT", "COMP_SAY_LOOT" } }) do
			local key = NS:CompanionVoicePick(case[1], case[3])
			s.ok(case[1], Starts(key, case[2]), key)
		end
		W.Free()
		NS.companionLastPet = nil
		NS:CompanionPet()
		s.ok("caresse", Starts(NS.companionBubbleLine, "COMP_SAY_PET_V_gfw"), NS.companionBubbleLine)
		W.Season(false)
		s.ok("hors saison : plus sa voix", not tostring(NS:CompanionVoicePick("KILL", { "Gnoll" })):find("_V_gfw", 1, true))
		s.check("[NOEL] sa voix dans chaque situation qui en a une (la commune sinon), plus hors saison")
		W.Done()
	end

	-- 5. Fin de saison ------------------------------------------------------------------------------------
	do
		Say("-- compagnons du Voile d'hiver : fin de saison")
		W.Reset(true)
		local regular = NS:CompanionData().appearance
		NS:CompanionSetAppearance("winter:gfw")
		local s = Steps()
		s.ok("en saison : il reste", NS:WinterCompanionsCheck() == false and NS:CompanionCurrentAppearance().id == "winter:gfw")
		W.Season(false)
		W.Free()
		s.ok("saison finie : l'habituel revient", NS:WinterCompanionsCheck() == true
			and NS:CompanionCurrentAppearance().id == regular and NS:CompanionData().winter.pick == nil)
		s.ok("au revoir : bulle et chat", Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_BYE_gfw") and Logged("repart vers le Nord"),
			NS.companionBubbleLine)
		W.Free()
		s.ok("une seule fois", NS:WinterCompanionsCheck() == false and NS.companionBubbleLine == nil)
		W.Reset(true)
		NS:CompanionSetAppearance("winter:snowman")
		W.on = false
		W.Free()
		NS:WinterCompanionsLogin()
		s.ok("connexion hors saison : départ dit", NS:CompanionData().winter.pick == nil
			and Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_BYE_snowman"), NS.companionBubbleLine)
		s.check("[NOEL] fin de saison : il repart (une fois, en jeu ou à la connexion), l'apparence habituelle revient")
		W.Done()
	end

	-- 6. Visite surprise ------------------------------------------------------------------------------------
	do
		Say("-- visite surprise de Grand-père Hiver")
		W.Reset(true)
		local s = Steps()
		s.ok("réglage activé par défaut, page du compagnon", NS.DEFAULTS.companionWinterVisit == true and (function()
			for _, page in ipairs(NS.OPTION_PAGES or {}) do
				if page.id == "companionMain" then
					for _, row in ipairs(page.rows) do if row.key == "companionWinterVisit" and row.kind == "bool" then return true end end
				end
			end
			return false
		end)())
		NS.winterVisitAt = Mock.now + 100
		s.ok("pas avant son heure", NS:WinterVisitTick() == false and not NS.winterVisited)
		NS.winterVisitAt = Mock.now - 1
		W.combat = true
		local ready, why = NS:WinterVisitReady()
		s.ok("combat", NS:WinterVisitTick() == false and not ready and why == "combat")
		W.combat, W.inside = false, true
		ready, why = NS:WinterVisitReady()
		s.ok("instance", not ready and why == "instance")
		W.inside = false
		NS:DB().companionWinterVisit = false
		ready, why = NS:WinterVisitReady()
		s.ok("réglage coupé", not ready and why == "setting")
		NS:DB().companionWinterVisit = nil
		W.Season(false)
		ready, why = NS:WinterVisitReady()
		s.ok("hors saison", not ready and why == "season")
		W.Season(true)
		s.check("[NOEL] visite : réglage par défaut, jamais avant son heure, en combat, en instance, réglage coupé ou hors saison")
		s = Steps()
		s.ok("il apparaît", NS:WinterVisitTick() == true and NS.winterVisitFrame and NS.winterVisitFrame:IsShown()
			and NS.winterVisitFrame.bubble:IsShown())
		local frame = NS.winterVisitFrame
		local text = frame.bubble.text.text or (frame.bubble.text.GetText and frame.bubble.text:GetText())
		local found = false
		for _, key in ipairs(NS.COMPANION_POOLS.WINTER_VISIT) do if NS.L[key] == text then found = true end end
		s.ok("une de ses répliques", found, text)
		local update = frame:GetScript("OnUpdate")
		update(frame, 1)
		local midAlpha = frame.shownAlpha
		update(frame, 4.8)
		s.ok("fondus d'entrée puis de sortie", midAlpha == 1 and frame.shownAlpha and frame.shownAlpha < 1 and frame:IsShown())
		frame:GetScript("OnMouseUp")(frame, "LeftButton")
		s.ok("un clic le renvoie", not frame:IsShown() and not frame.bubble:IsShown() and frame:GetScript("OnUpdate") == nil)
		NS:WinterVisitShow()
		NS.winterVisited = true
		frame:GetScript("OnUpdate")(frame, NS.WINTER_VISIT_TIME + 1)
		s.ok("repart seul", not frame:IsShown())
		NS.winterVisitAt = Mock.now - 1
		ready, why = NS:WinterVisitReady()
		s.ok("une fois par session", NS:WinterVisitTick() == false and why == "done")
		NS.winterVisited = nil
		NS:CompanionSetAppearance("winter:gfw")
		ready, why = NS:WinterVisitReady()
		s.ok("pas s'il voyage déjà avec toi", not ready and why == "here")
		s.check("[NOEL] visite : il apparaît avec une réplique, fondus, renvoyé d'un clic ou parti seul, une fois par session")
		W.Done()
	end

	-- 7. Haut fait souvenir ----------------------------------------------------------------------------------
	do
		Say("-- haut fait « Joyeux Voile d'hiver »")
		W.Reset(true)
		local def = NS:FeatDef("fun_winter_veil")
		Check("[NOEL] haut fait : Insolite, compte, drapeau winterVeil, code 175, nom et description FR/EN",
			def and def.cat == "fun" and def.scope == "account" and def.crit[1] == "flag" and def.crit[2] == "winterVeil"
			and def.n == 175 and NS.L.FEAT_fun_winter_veil == "Joyeux Voile d'hiver"
			and NS.FEAT_MENAGERIE_STRINGS.en.FEAT_fun_winter_veil == "Merry Winter Veil"
			and NS.FEAT_MENAGERIE_STRINGS.en.FEATD_flag_winterVeil ~= nil)
		local store = NS:FeatStore("account")
		store.flag.winterVeil = nil
		local s = Steps()
		NS:CompanionTick(3600)
		s.ok("sans compagnon de saison", store.flag.winterVeil == nil)
		NS:CompanionSetAppearance("winter:snowman")
		NS:CompanionTick(1800)
		s.ok("une demi-heure : pas encore", store.flag.winterVeil == nil)
		NS:CompanionTick(1800)
		s.ok("une heure : posé", store.flag.winterVeil ~= nil)
		store.flag.winterVeil = nil
		local data = NS:CompanionData()
		data.winter.feat, data.winter.time, data.winter.caps = nil, 0, 9
		NS:CaptureResolve({ success = true, target = { npcID = 990214, name = "Loup d'essai", class = "normal", level = 10 } })
		s.ok("dix captures avec lui : posé", store.flag.winterVeil ~= nil and data.winter.caps == 10)
		NS:CaptureData().creatures[990214] = nil
		store.flag.winterVeil = nil
		data.winter.feat, data.winter.time, data.winter.caps = nil, 0, 0
		W.Season(false)
		NS:CompanionTick(7200)
		s.ok("hors saison : plus", store.flag.winterVeil == nil)
		s.check("[NOEL] haut fait gagné après une heure ou dix captures avec un compagnon de saison, jamais hors saison")
		W.Done()
	end
end
