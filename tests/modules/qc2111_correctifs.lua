-- QuestCompanion 2.11.1 : correctifs des retours en jeu de la 2.11.0 :
-- bandeau de guilde sur deux lignes (C1), modèle du compagnon éclairé et
-- cadré par type de créature (C2), résumé de la colonne du carnet borné à
-- sa largeur (C4), plaques de chiffres centrées (C5), « Changer de
-- compagnon ? » au-dessus du carnet, Échap d'abord (C6).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local GLOBALS = { "InCombatLockdown", "UnitAffectingCombat", "UnitLevel", "CreateVector3D", "CreateColor" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local FIELDS = { "journalFrame", "companionFrame", "companionBubble", "effectsConfirm", "guildFeatToast" }

local function Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache, NS.errors = nil, {}, {}
	NS:DB().journalState = nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:CompanionData().tutoDone = true
end
local function Done()
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache = nil, {}
	NS:DB().journalState = nil
	ResetWorld()
end
local function Open(kind)
	local frame = NS:ToggleJournal(true)
	if kind then NS:SelectJournalKind(kind) end
	return frame
end

-- Un PlayerModel simulé, avec sa lumière
local METHODS = { "SetCamDistanceScale", "SetPortraitZoom", "SetPosition", "SetModelScale", "SetModelAlpha",
	"SetDisplayInfo", "SetCreature", "ClearModel", "SetAlpha" }
local function FakeModel(light)
	local m = { calls = {}, last = {}, scripts = {}, shown = false, lights = {} }
	for _, name in ipairs(METHODS) do
		m[name] = function(self, ...)
			self.calls[name] = (self.calls[name] or 0) + 1
			self.last[name] = (...)
		end
	end
	function m:GetLight() if light then return light[1], light[2] end return false, nil end
	function m:SetLight(...) self.lights[#self.lights + 1] = { ... } end
	function m:Show() self.shown = true end
	function m:Hide() self.shown = false end
	function m:IsShown() return self.shown end
	function m:HookScript(kind, fn) self.scripts[kind] = fn end
	return m
end

-- C2. Modèle du compagnon : opacité, lumière ------------------------------------------------------------
do
	Say("-- 2.11.1 : C2, modèle du compagnon éclairé")
	Reset("azeroth")
	_G.CreateVector3D = function(x, y, z) return { x = x, y = y, z = z } end
	_G.CreateColor = function(r, g, b) return { r = r, g = g, b = b } end
	local m = FakeModel()
	NS.ShowModel(m, { npc = 11 }, "companion")
	NS.ModelSetAlpha(m, 1)
	Check("[C2111] opaque au chargement : jamais SetModelAlpha(1) (rendu translucide du client)", m.calls.SetModelAlpha == nil)
	local lit = m.lights[#m.lights]
	Check("[C2111] lumière d'origine éteinte : la lumière blanche par défaut", lit and lit[1] == true and type(lit[2]) == "table"
		and lit[2].ambientIntensity == NS.MODEL_LIGHT.ambient and lit[2].diffuseColor.g == 1)
	local before = #m.lights
	m.scripts.OnModelLoaded(m)
	Check("[C2111] fin du chargement : la lumière reposée avec la caméra", #m.lights == before + 1)
	local shiny = FakeModel({ true, "origine" })
	NS.ShowModel(shiny, { npc = 12, shiny = true }, "companion")
	shiny.scripts.OnModelLoaded(shiny)
	local gold = shiny.lights[#shiny.lights]
	Check("[C2111] brillante : la lumière dorée tient après le chargement", gold and type(gold[2]) == "table"
		and gold[2].ambientColor.g < 1)

	-- estompe puis retour : modèle rechargé
	local frame = NS:EnsureCompanionFrame()
	local real = frame and frame.model
	local cm = FakeModel()
	if frame then frame.model = cm end
	NS:CompanionApplyModel()
	local loads = (cm.calls.SetDisplayInfo or 0) + (cm.calls.SetCreature or 0)
	Check("[C2111] compagnon affiché sans SetModelAlpha", frame and loads >= 1 and cm.calls.SetModelAlpha == nil)
	_G.InCombatLockdown = function() return true end
	NS:DB().companionCombatFade = true
	NS:CompanionApplyContext()
	Check("[C2111] combat : estompé (35 %)", cm.last.SetModelAlpha == NS.COMPANION_COMBAT_ALPHA)
	_G.InCombatLockdown = function() return false end
	NS.companionFighting = nil
	NS:CompanionApplyContext()
	local after = (cm.calls.SetDisplayInfo or 0) + (cm.calls.SetCreature or 0)
	Check("[C2111] fin de combat : opacité 1 et modèle rechargé (rendu et lumière neufs)", cm.last.SetModelAlpha == 1
		and after == loads + 1 and not cm.alphaDirty, loads .. " -> " .. after)
	local calls = cm.calls.SetModelAlpha
	NS:CompanionApplyContext()
	Check("[C2111] hors combat ensuite : plus rien de reposé", cm.calls.SetModelAlpha == calls
		and (cm.calls.SetDisplayInfo or 0) + (cm.calls.SetCreature or 0) == after)
	if frame then frame.model = real end
	Done()
end

-- C2. Taille par type de créature -----------------------------------------------------------------------
do
	Say("-- 2.11.1 : C2, distance du modèle par type")
	Reset("azeroth")
	local cap = NS:CaptureData().creatures
	cap[501] = { type = "Draconien", normal = true }
	cap[502] = { type = "Bête", normal = true }
	cap[503] = { type = "Critter", normal = true }
	cap[504] = { type = "Inconnu", normal = true }
	local T = NS.COMPANION_MODEL_TYPE_CAM
	local dragon = NS:CompanionModelCam({ npc = 501 }, "pied")
	local beast = NS:CompanionModelCam({ npc = 502 }, "pied")
	local critter = NS:CompanionModelCam({ npc = 503 }, "pied")
	Check("[C2111] dragon plus loin, bête au milieu, bestiole plus près", dragon > beast and beast > critter
		and dragon == T["Draconien"] and critter == T.Critter)
	Check("[C2111] type inconnu : la distance par défaut", NS:CompanionModelCam({ npc = 504 }, "pied") == T.default
		and NS:CompanionModelCam({ npc = 999 }, "pied") == T.default)
	Check("[C2111] noms FR et EN pour chaque type", T["Draconien"] == T.Dragonkin and T["Géant"] == T.Giant
		and T["Bête"] == T.Beast and T["Mort-vivant"] == T.Undead)
	Check("[C2111] cadrage gardé : portrait < buste < pied", NS:CompanionModelCam({ npc = 502 }, "portrait")
		< NS:CompanionModelCam({ npc = 502 }, "buste") and NS:CompanionModelCam({ npc = 502 }, "buste") < beast)
	NS.COMPANION_MODEL_OVERRIDES[502] = { cam = 3, y = -0.2 }
	NS.COMPANION_MODEL_OVERRIDES.d777 = { cam = 0.9 }
	local cam, y = NS:CompanionModelCam({ npc = 502 }, "pied")
	Check("[C2111] surcharge par espèce (cam, y)", cam == 3 and y == -0.2)
	Check("[C2111] surcharge par displayID d'abord", NS:CompanionModelCam({ npc = 502, display = 777 }, "pied") == 0.9)
	NS.COMPANION_MODEL_OVERRIDES[502], NS.COMPANION_MODEL_OVERRIDES.d777 = nil, nil
	-- le compagnon capturé reçoit la distance de son type
	local m = FakeModel()
	NS.ShowModel(m, { npc = 501, cam = NS:CompanionModelCam({ npc = 501 }, "buste") }, "companion")
	Check("[C2111] ShowModel : la distance posée, aucun zoom « tête » (créature sauvage)",
		math.abs(m.last.SetCamDistanceScale - T["Draconien"] * NS.COMPANION_FRAMING_CAM.buste) < 1e-9 and m.last.SetPortraitZoom == 0)
	Check("[C2111] plus petit qu'en 2.11.0 (2,4 pour tous) : bête rapprochée", beast < 2.4)
	for npc = 501, 504 do cap[npc] = nil end
	Done()
end

-- C1. Bandeau de guilde -----------------------------------------------------------------------------------
do
	Say("-- 2.11.1 : C1, bandeau de guilde")
	Reset("azeroth")
	local LAY = NS.AZEROTH_LAYOUT
	local long = "Dresseur confirmé Dyokrion Aeternalis a capturé 51 espèces, un exploit de longue haleine !"
	NS:GuildFeatsShowToast({ key = "a", sender = "Dyokrion-Royaume", feat = { kind = "r" }, score = 10, at = Mock.now,
		info = { kind = "r", line = long, sub = "Nouveau titre : Dresseur confirmé" } })
	local f = NS.guildFeatToast
	Check("[C2111] ligne trop longue : deux lignes, coupure aux mots", f and f.azeroth and f.text.fitLines == 2
		and f.text.wordWrap == true and (f.text.maxLines == nil or f.text.maxLines == 2))
	Check("[C2111] … nom remonté, sous-ligne descendue, dans le bandeau", f.text.lastPoint.y == LAY.nameY2
		and f.stars.lastPoint.y == LAY.starsY2 and LAY.starsY2 > -LAY.h + 20)
	Check("[C2111] … pas plus petit que le minimum lisible", (f.text.fitSize or 0) >= LAY.nameMin)
	NS:GuildFeatsHideToast()
	NS:GuildFeatsShowToast({ key = "b", sender = "Xan-Royaume", feat = { kind = "s" }, score = 10, at = Mock.now,
		info = { line = "Xan a capturé une brillante !", shiny = true, class = "normal", name = "Sanglier", stars = 2 } })
	Check("[C2111] ligne courte : une ligne, places d'origine", f.text.fitLines == 1 and f.text.wordWrap == false
		and f.text.lastPoint.y == LAY.nameY and f.stars.lastPoint.y == LAY.starsY)
	NS:GuildFeatsHideToast()
	-- palier : le titre n'est pas dit deux fois
	local code = NS.FEAT_RANK_TITLES and NS.FEAT_RANK_TITLES.trainer
	NS:GuildFeatsReset()
	local info = code and NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~" .. code .. "~f"), "Bob-Royaume")
	Check("[C2111] palier : il porte déjà le nouveau titre, le nom seul dans la ligne", info
		and info.line == "Bob a capturé 25 espèces !" and info.sub ~= nil and info.sub:find("Nouveau titre", 1, true) ~= nil,
		info and info.line)
	Done()
end

-- C4. Colonne du carnet : résumé borné à sa largeur -----------------------------------------------------------
do
	Say("-- 2.11.1 : C4, résumé de la colonne")
	for _, style in ipairs({ "azeroth", "sobre" }) do
		Reset(style)
		local f = Open("evolution")
		local box = f.navSummary
		local navW = style == "azeroth" and NS.CARNET_LAYOUT.nav or NS.JOURNAL_LAYOUT.nav
		local x = box.lastPoint.x or 0
		local inner = navW - 2 * x
		local ok = box.fitW and box.fitW <= inner and box:GetWidth() == box.fitW
		for _, block in ipairs({ box.pet, box.zone, box.missions }) do
			ok = ok and block:GetWidth() == box.fitW and block.rule:GetWidth() == box.fitW
		end
		for _, row in ipairs(box.pet.needs) do ok = ok and NS.JOURNAL_NAVSUM.labelW + row.bar:GetWidth() <= box.fitW end
		ok = ok and box.zone.bar:GetWidth() <= box.fitW
		for _, row in ipairs(box.missions.rows) do
			ok = ok and NS.JOURNAL_NAVSUM.labelW + 3 * 14 + row.left:GetWidth() <= box.fitW
		end
		Check("[C2111] " .. style .. " : barres, % et jours dans la largeur intérieure (marges égales)", ok,
			tostring(box.fitW) .. " / " .. tostring(inner))
	end
	Done()
end

-- C5. Plaques de chiffres : groupe centré -----------------------------------------------------------------------
do
	Say("-- 2.11.1 : C5, plaques centrées")
	for _, style in ipairs({ "sobre", "azeroth" }) do
		Reset(style)
		local f = Open("evolution")
		local S = NS.JOURNAL_STAT_LAYOUT
		local ok, info = true, ""
		for key, tile in pairs(f.evo.stats) do
			local vp, lp = tile.value.lastPoint, tile.label.lastPoint
			local hv = (select(2, tile.value:GetFont()) or 16) * S.glyph
			local hl = (select(2, tile.label:GetFont()) or 11) * S.glyph
			local top, bottom = vp.y + hv / 2, lp.y - hl / 2
			-- le groupe (haut du chiffre, bas du libellé) est centré à 1 px près
			if not (vp.point == "CENTER" and lp.point == "CENTER" and vp.relTo == tile and math.abs(top + bottom) <= 1
				and (vp.y - hv / 2) - (lp.y + hl / 2) <= S.gap + 1) then
				ok, info = false, key .. " " .. vp.y .. "/" .. lp.y
			end
		end
		Check("[C2111] " .. style .. " : chiffre et libellé groupés au centre de la plaque", ok, info)
	end
	Done()
end

-- C6. « Changer de compagnon ? » au-dessus du carnet --------------------------------------------------------------
do
	Say("-- 2.11.1 : C6, confirmation au-dessus du carnet")
	for _, style in ipairs({ "azeroth", "sobre" }) do
		Reset(style)
		local journal = Open("menagerie")
		journal:SetFrameLevel(30)
		local d = NS:EnsureEffectsConfirm()
		function d:EnableKeyboard(on) self.keyboard = on end
		function d:SetPropagateKeyboardInput(on) self.propagate = on end
		function d:Raise() self.raised = true end
		local applied = false
		d.pending = { apply = function() applied = true end }
		Check("[C2111] " .. style .. " : posée au centre du carnet", NS:EffectsConfirmPlace(d) == "journal"
			and d.lastPoint.point == "CENTER" and d.lastPoint.relTo == journal)
		Check("[C2111] " .. style .. " : strate au-dessus du carnet, niveau relevé", d.strata == "FULLSCREEN_DIALOG"
			and d:GetFrameLevel() > journal:GetFrameLevel() and d.raised and journal.strata ~= "FULLSCREEN_DIALOG")
		Check("[C2111] " .. style .. " : clavier pris, les autres touches passent", d.keyboard == true and d.propagate == true)
		d:Show()
		d:GetScript("OnKeyDown")(d, "W")
		Check("[C2111] " .. style .. " : une autre touche passe au jeu", d.propagate == true and d:IsShown())
		d:GetScript("OnKeyDown")(d, "ESCAPE")
		Check("[C2111] " .. style .. " : Échap ferme la question seule (non), le carnet reste", d.propagate == false
			and not d:IsShown() and not applied and journal:IsShown() and d.pending == nil)
		-- carnet fermé pendant la question : elle se ferme aussi
		d.pending = { apply = function() applied = true end }
		NS:EffectsConfirmPlace(d)
		d:Show()
		journal:Hide()
		local onHide = journal.hooks and journal.hooks.OnHide
		if onHide and d:IsShown() then onHide(journal) end
		Check("[C2111] " .. style .. " : carnet fermé, question fermée sans réponse", not d:IsShown() and not applied)
		-- en combat : pas de clavier (SetPropagateKeyboardInput réservé)
		_G.InCombatLockdown = function() return true end
		d.keyboard, d.propagate = nil, nil
		journal:Show()
		NS:EffectsConfirmPlace(d)
		Check("[C2111] " .. style .. " : en combat, ni clavier ni appel réservé", d.keyboard == false and d.propagate == nil)
	end
	Done()
end
