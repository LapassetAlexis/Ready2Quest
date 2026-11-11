-- Modèles 3D et portraits (QuestCompanion 2.11.0 → 2.11.1, R2Q 1.32.0) : un
-- seul cadrage par ns.ShowModel (scène, fiche, compagnon ; aucune caméra posée
-- ailleurs), portrait 2D du jeu ou icône du type, sonde du displayID hors
-- combat ; modèle du compagnon opaque, éclairé, estompé en combat puis
-- rechargé ; distance de caméra par type de créature et surcharges ; une
-- seule alerte rouge quand Ready2Quest montre déjà son anneau d'aggro.
local Check, Say, ResetWorld, QNS, RNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.NS, T.Mock

local GLOBALS = { "InCombatLockdown", "CreateVector3D", "CreateColor", "SetPortraitTextureFromCreatureDisplayID", "Ready2Quest" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end

-- Un PlayerModel simulé : garde chaque appel et sa dernière valeur, et sa lumière
local MODEL_METHODS = { "SetCamDistanceScale", "SetPortraitZoom", "SetPosition", "SetModelScale", "SetModelAlpha",
	"SetDisplayInfo", "SetCreature", "ClearModel", "SetAlpha" }
local function FakeModel(refuse, light)
	local m = { calls = {}, last = {}, scripts = {}, shown = false, lights = {} }
	for _, name in ipairs(MODEL_METHODS) do
		m[name] = function(self, ...)
			if refuse and refuse[name] then error("refusé") end
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
local function Loads(m) return (m.calls.SetDisplayInfo or 0) + (m.calls.SetCreature or 0) end

-- 1. ns.ShowModel : un seul cadrage --------------------------------------------------------------
do
	Say("-- 2.11.0 : un seul cadrage des modèles 3D")
	ResetWorld()
	local m = FakeModel()
	local shown = QNS.ShowModel(m, { npc = 1 }, "stage")
	Check("[MOD] scène : créature posée, caméra 1,2, aucun zoom « tête »", shown and m.shown
		and m.last.SetCreature == 1 and m.last.SetCamDistanceScale == QNS.CAPTURE_STAGE_CAM and m.last.SetPortraitZoom == 0)
	m.last.SetCamDistanceScale = 9
	m.scripts.OnModelLoaded(m)
	Check("[MOD] caméra reposée à la fin du chargement (OnModelLoaded)", m.last.SetCamDistanceScale == QNS.CAPTURE_STAGE_CAM)
	QNS.ShowModel(m, { npc = 1 }, "stage")
	local kept = m.calls.SetCreature == 1
	QNS.ShowModel(m, { npc = 2 }, "stage")
	Check("[MOD] même créature : pas rechargée ; autre créature : rechargée", kept and m.calls.SetCreature == 2 and m.last.SetCreature == 2)
	local wild, mascot = FakeModel(), FakeModel()
	QNS.ShowModel(wild, { npc = 3, zoom = 1 }, "companion")
	QNS.ShowModel(mascot, { display = 4, npc = 3, zoom = 1 }, "companion")
	Check("[MOD] créature sauvage : jamais le zoom « portrait » ; mascotte (display) : le zoom du réglage",
		wild.last.SetPortraitZoom == 0 and mascot.last.SetDisplayInfo == 4 and mascot.last.SetPortraitZoom == 1
		and not mascot.calls.SetCreature)
	local broken = FakeModel({ SetCreature = true })
	Check("[MOD] chargement refusé ou sans créature : faux, modèle caché (l'appelant montre son repli)",
		QNS.ShowModel(broken, { npc = 5 }, "card") == false and not broken.shown and QNS.ShowModel(FakeModel(), {}, "card") == false)
	local card = FakeModel()
	QNS.ShowModel(card, { npc = 6 }, "card")
	local near = card.last.SetCamDistanceScale <= 1.2
	QNS.ShowModel(card, { npc = 6, epoch = 2 }, "card")
	Check("[MOD] fiche de dresseur : la créature vue de près (≤ 1,2), rechargée à chaque ouverture (epoch)", near
		and card.calls.SetCreature == 2, tostring(card.last.SetCamDistanceScale))
	-- garde-fou : aucun appel direct hors de ns.ShowModel
	local direct = {}
	for _, file in ipairs({ "Companion.lua", "CaptureStage.lua", "CaptureBatch.lua", "Capture.lua", "TrainerCard.lua" }) do
		local handle = io.open(ROOT_DIR and (ROOT_DIR .. file) or ((ADDON_ROOT or ".") .. "/QuestCompanion/" .. file), "r")
		local text = handle and handle:read("*a") or ""
		if handle then handle:close() end
		for line in text:gmatch("[^\n]+") do
			if not line:find("ModelCall%(") and not line:find("^%s*%-%-")
				and (line:find(":SetCamDistanceScale%(") or line:find(":SetPortraitZoom%(") or line:find("\"SetCamDistanceScale\"")
					or line:find("model%.SetCreature,") or line:find("model%.SetDisplayInfo,")) then
				direct[#direct + 1] = file .. " : " .. line
			end
		end
	end
	Check("[MOD] plus de caméra posée hors de ns.ShowModel (compagnon, scène, lot, fenêtre, fiche)", #direct == 0,
		table.concat(direct, " | "))
end

-- 2. Portrait 2D, sonde du displayID ------------------------------------------------------------
do
	Say("-- 2.11.0 : portrait 2D de la créature")
	ResetWorld()
	_G.SetPortraitTextureFromCreatureDisplayID = nil
	local tex = UIParent:CreateTexture()
	local noApi = QNS:CreaturePortrait(tex, { npcID = 70, type = "Bête" }) == "icon" and tex.texture ~= nil
	local painted
	_G.SetPortraitTextureFromCreatureDisplayID = function(t, id) painted = id; t.texture = "portrait:" .. id end
	Check("[MOD] sans l'API, ou displayID inconnu : l'icône du type", noApi and QNS:CreaturePortrait(tex, { npcID = 70 }) == "icon")
	QNS:CaptureAccount().display = { [70] = 1234 }
	Check("[MOD] displayID connu au compte : le portrait du jeu", QNS:CreaturePortrait(tex, { npcID = 70 }) == "portrait"
		and painted == 1234)
	-- la sonde : lit le displayID une fois, jamais en combat
	QNS:CaptureAccount().display = {}
	local probe = FakeModel()
	probe.SetSize, probe.SetPoint, probe.SetScript = function() end, function() end, function() end
	function probe:SetUnit(unit) self.unit = unit end
	function probe:GetDisplayInfo() return 777 end
	QNS.modelLearnProbe, QNS.modelLearnAt = probe, nil
	_G.InCombatLockdown = function() return true end
	local fighting = QNS:ModelLearnDisplay("target", 71) == nil and probe.unit == nil
	_G.InCombatLockdown = function() return false end
	Check("[MOD] sonde : rien en combat ; hors combat, displayID lu et gardé au compte", fighting
		and QNS:ModelLearnDisplay("target", 71) == 777 and QNS:CaptureAccount().display[71] == 777 and probe.unit == "target")
	QNS.modelLearnAt, probe.unit = nil, nil
	Check("[MOD] sonde : une espèce connue n'est pas relue", QNS:ModelLearnDisplay("target", 71) == 777 and probe.unit == nil)
	QNS.modelLearnProbe, QNS.modelLearnAt = nil, nil
	_G.InCombatLockdown = saved.InCombatLockdown
	_G.SetPortraitTextureFromCreatureDisplayID = saved.SetPortraitTextureFromCreatureDisplayID
end

-- 3. Modèle du compagnon : opaque, éclairé, estompé en combat (B7, C2) ------------------------------
do
	Say("-- 2.11.1 : modèle du compagnon, lumière et estompe")
	ResetWorld()
	Mock.InstallAtlas(true)
	QNS:AzerothAtlasOK(true)
	QNS:CompanionData().tutoDone = true
	_G.InCombatLockdown = function() return false end
	_G.CreateVector3D = function(x, y, z) return { x = x, y = y, z = z } end
	_G.CreateColor = function(r, g, b) return { r = r, g = g, b = b } end
	local m = FakeModel()
	QNS.ShowModel(m, { npc = 11 }, "companion")
	QNS.ModelSetAlpha(m, 1)
	local lit = m.lights[#m.lights]
	local before = #m.lights
	m.scripts.OnModelLoaded(m)
	Check("[MOD] opaque sans SetModelAlpha(1) (rendu translucide du client) ; lumière blanche par défaut, reposée au chargement",
		m.calls.SetModelAlpha == nil and lit and lit[1] == true and type(lit[2]) == "table"
		and lit[2].ambientIntensity == QNS.MODEL_LIGHT.ambient and lit[2].diffuseColor.g == 1 and #m.lights == before + 1)
	local shiny = FakeModel(nil, { true, "origine" })
	QNS.ShowModel(shiny, { npc = 12, shiny = true }, "companion")
	shiny.scripts.OnModelLoaded(shiny)
	local gold = shiny.lights[#shiny.lights]
	Check("[MOD] brillante : la lumière dorée tient après le chargement", gold and type(gold[2]) == "table" and gold[2].ambientColor.g < 1)
	local frame = QNS:EnsureCompanionFrame()
	local real = frame and frame.model
	local cm = FakeModel()
	if frame then frame.model = cm end
	QNS:CompanionApplyModel()
	local loads = Loads(cm)
	_G.InCombatLockdown = function() return true end
	QNS:DB().companionCombatFade = true
	QNS:CompanionApplyContext()
	local faded = frame and loads >= 1 and cm.last.SetModelAlpha == QNS.COMPANION_COMBAT_ALPHA
	cm.last.SetModelAlpha = 1
	cm.scripts.OnModelLoaded(cm)
	Check("[MOD] combat : le modèle passe à 35 % avec le cadre, un rechargement garde l'estompe", faded
		and cm.last.SetModelAlpha == QNS.COMPANION_COMBAT_ALPHA, tostring(cm.last.SetModelAlpha))
	loads = Loads(cm)
	_G.InCombatLockdown = function() return false end
	QNS.companionFighting = nil
	QNS:CompanionApplyContext()
	local after = Loads(cm)
	local calls = cm.calls.SetModelAlpha
	QNS:CompanionApplyContext()
	Check("[MOD] fin de combat : opacité 1, rechargé une fois (rendu et lumière neufs), puis plus rien", cm.last.SetModelAlpha == 1
		and after == loads + 1 and not cm.alphaDirty and cm.calls.SetModelAlpha == calls and Loads(cm) == after, loads .. " -> " .. after)
	if frame then frame.model = real end
	for _, name in ipairs({ "InCombatLockdown", "CreateVector3D", "CreateColor" }) do _G[name] = saved[name] end
	Mock.InstallAtlas(nil)
end

-- 4. Distance de caméra par type de créature (C2) ----------------------------------------------------
do
	Say("-- 2.11.1 : distance du modèle par type")
	ResetWorld()
	local cap = QNS:CaptureData().creatures
	cap[501] = { type = "Draconien", normal = true }
	cap[502] = { type = "Bête", normal = true }
	cap[503] = { type = "Critter", normal = true }
	cap[504] = { type = "Inconnu", normal = true }
	local TC = QNS.COMPANION_MODEL_TYPE_CAM
	local dragon = QNS:CompanionModelCam({ npc = 501 }, "pied")
	local beast = QNS:CompanionModelCam({ npc = 502 }, "pied")
	local critter = QNS:CompanionModelCam({ npc = 503 }, "pied")
	Check("[MOD] dragon plus loin, bête au milieu, bestiole plus près ; inconnu : distance par défaut", dragon > beast and beast > critter
		and dragon == TC["Draconien"] and critter == TC.Critter and QNS:CompanionModelCam({ npc = 504 }, "pied") == TC.default
		and QNS:CompanionModelCam({ npc = 999 }, "pied") == TC.default)
	Check("[MOD] noms FR et EN pour chaque type", TC["Draconien"] == TC.Dragonkin and TC["Géant"] == TC.Giant
		and TC["Bête"] == TC.Beast and TC["Mort-vivant"] == TC.Undead)
	Check("[MOD] cadrage gardé : portrait < buste < pied", QNS:CompanionModelCam({ npc = 502 }, "portrait")
		< QNS:CompanionModelCam({ npc = 502 }, "buste") and QNS:CompanionModelCam({ npc = 502 }, "buste") < beast)
	QNS.COMPANION_MODEL_OVERRIDES[502] = { cam = 3, y = -0.2 }
	QNS.COMPANION_MODEL_OVERRIDES.d777 = { cam = 0.9 }
	local cam, y = QNS:CompanionModelCam({ npc = 502 }, "pied")
	Check("[MOD] surcharge par espèce (cam, y), par displayID d'abord", cam == 3 and y == -0.2
		and QNS:CompanionModelCam({ npc = 502, display = 777 }, "pied") == 0.9)
	QNS.COMPANION_MODEL_OVERRIDES[502], QNS.COMPANION_MODEL_OVERRIDES.d777 = nil, nil
	local m = FakeModel()
	QNS.ShowModel(m, { npc = 501, cam = QNS:CompanionModelCam({ npc = 501 }, "buste") }, "companion")
	Check("[MOD] ShowModel : la distance du type posée, aucun zoom « tête » (créature sauvage)",
		math.abs(m.last.SetCamDistanceScale - TC["Draconien"] * QNS.COMPANION_FRAMING_CAM.buste) < 1e-9 and m.last.SetPortraitZoom == 0)
	for npc = 501, 504 do cap[npc] = nil end
end

-- 5. Une seule alerte rouge avec les deux add-ons (fiche 26) ------------------------------------------
do
	Say("-- 2.11.0 / 1.32.0 : une seule alerte rouge avec les deux add-ons")
	ResetWorld()
	local savedRings = RNS.aggroRings
	_G.Ready2Quest = RNS
	local ring = { verdict = "red", shown = true }
	function ring:IsShown() return self.shown end
	RNS.aggroRings = { plate = ring }
	QNS:DB().companionAggroBlink = "always"
	Check("[MOD] anneau rouge de Ready2Quest posé : le compagnon ne clignote pas en plus",
		RNS:AggroDangerShown() and QNS:CompanionAggroDeferred() and not QNS:CompanionAggroAllowed())
	ring.shown = false
	Check("[MOD] pas d'anneau rouge : l'alerte du compagnon revient", not QNS:CompanionAggroDeferred() and QNS:CompanionAggroAllowed())
	ring.shown = true
	RNS:DB().aggroEnabled = false
	local cut = not QNS:CompanionAggroDeferred()
	RNS:DB().aggroEnabled = nil
	_G.Ready2Quest = nil
	Check("[MOD] aggro de Ready2Quest coupée, ou Ready2Quest absent : le compagnon garde son alerte", cut
		and not QNS:CompanionAggroDeferred())
	RNS.aggroRings = savedRings
	QNS:DB().companionAggroBlink = nil
end

for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
ResetWorld()
