-- QC 2.11.0 / R2Q 1.32.0 : un seul cadrage des modèles 3D et portrait 2D
-- (fiche 10), modèle estompé en combat (B7), humeur lisible et rangs en
-- Sobre (fiche 09), textures du client par référence (fiche 12), une seule
-- alerte rouge quand les deux add-ons sont là (fiche 26).
local Check, Say, ResetWorld, QNS, RNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.NS, T.Mock
local Theme = QNS.Theme

-- Un PlayerModel simulé : garde chaque appel et sa dernière valeur
local MODEL_METHODS = { "SetCamDistanceScale", "SetPortraitZoom", "SetPosition", "SetModelScale", "SetModelAlpha",
	"SetDisplayInfo", "SetCreature", "ClearModel", "SetAlpha" }
local function FakeModel(refuse)
	local m = { calls = {}, last = {}, scripts = {}, shown = false }
	for _, name in ipairs(MODEL_METHODS) do
		m[name] = function(self, ...)
			if refuse and refuse[name] then error("refusé") end
			self.calls[name] = (self.calls[name] or 0) + 1
			self.last[name] = (...)
		end
	end
	function m:Show() self.shown = true end
	function m:Hide() self.shown = false end
	function m:IsShown() return self.shown end
	function m:HookScript(kind, fn) self.scripts[kind] = fn end
	return m
end

local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
local function Ratio(a, b)
	local x, y = Lum(a), Lum(b)
	if x < y then x, y = y, x end
	return (x + 0.05) / (y + 0.05)
end
local function Over(top, bottom, alpha)
	return { top[1] * alpha + bottom[1] * (1 - alpha), top[2] * alpha + bottom[2] * (1 - alpha),
		top[3] * alpha + bottom[3] * (1 - alpha) }
end

-- 1. ns.ShowModel ----------------------------------------------------------------
do
	Say("-- 2.11.0 : un seul cadrage des modèles 3D")
	ResetWorld()
	local m = FakeModel()
	local shown = QNS.ShowModel(m, { npc = 1 }, "stage")
	Check("[M211] stage : créature posée, caméra 1,2, aucun zoom « tête »", shown and m.shown
		and m.last.SetCreature == 1 and m.last.SetCamDistanceScale == QNS.CAPTURE_STAGE_CAM and m.last.SetPortraitZoom == 0)
	m.last.SetCamDistanceScale = 9
	m.scripts.OnModelLoaded(m)
	Check("[M211] caméra reposée à la fin du chargement (OnModelLoaded)", m.last.SetCamDistanceScale == QNS.CAPTURE_STAGE_CAM)
	QNS.ShowModel(m, { npc = 1 }, "stage")
	Check("[M211] même créature : pas rechargée", m.calls.SetCreature == 1)
	QNS.ShowModel(m, { npc = 2 }, "stage")
	Check("[M211] autre créature : rechargée", m.calls.SetCreature == 2 and m.last.SetCreature == 2)

	local wild = FakeModel()
	QNS.ShowModel(wild, { npc = 3, zoom = 1 }, "companion")
	Check("[M211] créature sauvage : jamais le zoom « portrait », même demandé", wild.last.SetPortraitZoom == 0)
	local mascot = FakeModel()
	QNS.ShowModel(mascot, { display = 4, npc = 3, zoom = 1 }, "companion")
	Check("[M211] mascotte (display) : le zoom du réglage", mascot.last.SetDisplayInfo == 4 and mascot.last.SetPortraitZoom == 1
		and not mascot.calls.SetCreature)

	local broken = FakeModel({ SetCreature = true })
	Check("[M211] chargement refusé : faux, modèle caché (l'appelant montre son repli)",
		QNS.ShowModel(broken, { npc = 5 }, "card") == false and not broken.shown)
	Check("[M211] sans créature : faux", QNS.ShowModel(FakeModel(), {}, "card") == false)

	local card = FakeModel()
	QNS.ShowModel(card, { npc = 6 }, "card")
	Check("[M211] fiche de dresseur : la créature capturée n'est plus vue de loin (≤ 1,2)",
		card.last.SetCamDistanceScale <= 1.2, tostring(card.last.SetCamDistanceScale))
	QNS.ShowModel(card, { npc = 6, epoch = 2 }, "card")
	Check("[M211] nouvelle ouverture de la fiche (epoch) : rechargée", card.calls.SetCreature == 2)

	-- plus aucun appel direct hors de ns.ShowModel dans les fichiers du lot
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
	Check("[M211] plus de caméra posée hors de ns.ShowModel (compagnon, scène, lot, fenêtre, fiche)", #direct == 0,
		table.concat(direct, " | "))
end

-- 2. Portrait 2D ---------------------------------------------------------------
do
	Say("-- 2.11.0 : portrait 2D de la créature")
	ResetWorld()
	local saved = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
	_G.SetPortraitTextureFromCreatureDisplayID = nil
	local tex = UIParent:CreateTexture()
	Check("[M211] sans l'API : l'icône du type", QNS:CreaturePortrait(tex, { npcID = 70, type = "Bête" }) == "icon"
		and tex.texture ~= nil)
	local painted
	_G.SetPortraitTextureFromCreatureDisplayID = function(t, id) painted = id; t.texture = "portrait:" .. id end
	Check("[M211] API là mais displayID inconnu : toujours l'icône", QNS:CreaturePortrait(tex, { npcID = 70 }) == "icon")
	QNS:CaptureAccount().display = { [70] = 1234 }
	Check("[M211] displayID connu au compte : le portrait du jeu", QNS:CreaturePortrait(tex, { npcID = 70 }) == "portrait"
		and painted == 1234)

	-- la sonde : lit le displayID une fois, jamais en combat
	QNS:CaptureAccount().display = {}
	local probe = FakeModel()
	probe.SetSize, probe.SetPoint, probe.SetScript = function() end, function() end, function() end
	function probe:SetUnit(unit) self.unit = unit end
	function probe:GetDisplayInfo() return 777 end
	QNS.modelLearnProbe, QNS.modelLearnAt = probe, nil
	local savedCombat = rawget(_G, "InCombatLockdown")
	_G.InCombatLockdown = function() return true end
	Check("[M211] sonde : rien en combat", QNS:ModelLearnDisplay("target", 71) == nil and probe.unit == nil)
	_G.InCombatLockdown = function() return false end
	Check("[M211] sonde : displayID lu et gardé au compte", QNS:ModelLearnDisplay("target", 71) == 777
		and QNS:CaptureAccount().display[71] == 777 and probe.unit == "target")
	QNS.modelLearnAt = nil
	probe.unit = nil
	Check("[M211] sonde : une espèce connue n'est pas relue", QNS:ModelLearnDisplay("target", 71) == 777 and probe.unit == nil)
	_G.InCombatLockdown = savedCombat
	QNS.modelLearnProbe, QNS.modelLearnAt = nil, nil
	_G.SetPortraitTextureFromCreatureDisplayID = saved
end

-- 3. B7 : le modèle s'estompe avec le cadre ------------------------------------------
do
	Say("-- 2.11.0 : le modèle 3D estompé en combat (B7)")
	ResetWorld()
	local frame = QNS:EnsureCompanionFrame()
	local m = FakeModel()
	local before = frame and frame.model
	if frame then frame.model = m end
	local saved = rawget(_G, "InCombatLockdown")
	_G.InCombatLockdown = function() return true end
	QNS:DB().companionCombatFade = true
	QNS:CompanionApplyContext()
	Check("[M211] combat : le modèle aussi passe à 35 % (SetModelAlpha)", frame and m.last.SetModelAlpha == QNS.COMPANION_COMBAT_ALPHA,
		tostring(m.last.SetModelAlpha))
	m.framing = nil
	QNS.ShowModel(m, { npc = 9 }, "companion")
	m.last.SetModelAlpha = 1
	m.scripts.OnModelLoaded(m)
	Check("[M211] un rechargement garde l'estompe", m.last.SetModelAlpha == QNS.COMPANION_COMBAT_ALPHA)
	_G.InCombatLockdown = function() return false end
	QNS.companionFighting = nil
	QNS:CompanionApplyContext()
	Check("[M211] fin de combat : le modèle revient à 1", m.last.SetModelAlpha == 1)
	_G.InCombatLockdown = saved
	if frame then frame.model = before end
end

-- 4. Fiche 09 : humeur sur sa bande, rangs ---------------------------------------------
do
	Say("-- 2.11.0 : humeur lisible en Sobre, noms élite/rare")
	ResetWorld()
	local frame = QNS:EnsureCompanionFrame()
	QNS:CompanionRefreshLabels()
	local a = QNS.CompanionPlateAlpha()
	Check("[M211] Sobre : la bande sombre sous le nom et l'humeur", frame and frame.plate and frame.plate:IsShown()
		and frame.plate.height == QNS.COMPANION_PLATE_H)
	local c = frame and frame.mood.textColor or frame and { frame.mood:GetTextColor() }
	Check("[M211] humeur en TEXT", c and math.abs(c[1] - Theme.TEXT[1]) < 0.001, c and tostring(c[1]))
	local white, parchment = { 1, 1, 1 }, { 0.85, 0.78, 0.62 }
	local r1 = Ratio(Theme.TEXT, Over(Theme.INK, white, a))
	local r2 = Ratio(Theme.TEXT, Over(Theme.INK, parchment, a))
	Check("[M211] humeur ≥ 4,5:1 sur sol blanc et parchemin clair (bande comprise)", r1 >= 4.5 and r2 >= 4.5,
		string.format("%.2f / %.2f", r1, r2))
	local name = Ratio(Theme.PARCHMENT, Over(Theme.INK, white, a))
	Check("[M211] nom ≥ 4,5:1 sur la bande", name >= 4.5, string.format("%.2f", name))
	if frame then
		frame.uiStyle = "azeroth"
		QNS:CompanionApplySobrePlate()
		Check("[M211] Azeroth : la bande du Sobre se cache (sa plaque porte le texte)", not frame.plate:IsShown())
		frame.uiStyle = "sobre"
		QNS:CompanionApplySobrePlate()
		Check("[M211] retour en Sobre : la bande revient", frame.plate:IsShown())
	end

	local elite, rare = QNS:CaptureRarity({ class = "elite" }), QNS:CaptureRarity({ class = "rareelite" })
	local fb = QNS.CAPTURE_RANK_FALLBACK
	Check("[M211] rangs : la marque reste la couleur du jeu, le nom prend la variante claire",
		elite.color == fb.elite.mark and rare.color == fb.rare.mark and elite.text ~= elite.color and rare.text ~= rare.color)
	local worst = 99
	for _, bg in ipairs({ Theme.ROW, Theme.WINDOW, Theme.FIELD }) do
		for _, r in ipairs({ elite, rare }) do worst = math.min(worst, Ratio(r.text, bg)) end
	end
	Check("[M211] noms élite et rare ≥ 4,5:1 sur ROW, WINDOW, FIELD", worst >= 4.5, string.format("%.2f", worst))
	if type(Theme.RANK) == "table" and Theme.RankKey then
		Check("[M211] le nom suit le jeton du socle (Theme.RANK)", elite.text == Theme.RANK[Theme.RankKey("elite")])
	end
end

-- 5. Fiche 12 : textures du client, nos fichiers en repli ----------------------------------
do
	Say("-- 2.11.0 / 1.32.0 : textures du client par référence")
	ResetWorld()
	local tex = UIParent:CreateTexture()
	Mock.InstallAtlas(nil)
	-- 2.12.1 : plus de repli à nous (images supprimées)
	Check("[M211] sans atlas : texture vide, aucune image à nous", QNS.CaptureArtPaint(tex, "rays") == nil
		and tex.texture == nil and not tex.clientArt and QNS.CAPTURE_ART.rays == nil)
	Mock.InstallAtlas(true)
	local expect = { rays = "ArtifactsFX-StarBurst", halo = "ChallengeMode-SoftYellowGlow", sparks = "Artifacts-Anim-Sparks",
		stars = "auctionhouse-icon-favorite", ribbon = "BossBanner-BgBanner-Mid", ground = "ChallengeMode-SoftYellowGlow" }
	local ok, got = true, {}
	for role, atlas in pairs(expect) do
		local t = UIParent:CreateTexture()
		if QNS.CaptureArtPaint(t, role) ~= "client" or t.atlas ~= atlas or not t.clientArt then ok = false; got[#got + 1] = role end
	end
	Check("[M211] atlas du client : rayons, halo, étincelles, étoiles, bannière, ombre au sol", ok, table.concat(got, ","))
	Check("[M211] pas de « Bonus-ToastBanner » (écusson bleu sur Forever)", QNS.CAPTURE_CLIENT_ART.ribbon.atlas ~= "Bonus-ToastBanner")
	Check("[M211] le filet, ses cordes et le paquet restent les nôtres", QNS.CaptureArtPaint(tex, "net") == "own"
		and QNS.CaptureArtPaint(tex, "rope") == "own" and QNS.CaptureArtPaint(tex, "bundle") == "own")
	Mock.InstallAtlas({ ["ArtifactsFX-StarBurst"] = true })
	Check("[M211] atlas manquant : texture vide", QNS.CaptureArtPaint(tex, "rays") == nil and tex.texture == nil)
	-- 2.14.0 : hors décor du Voile d'hiver (l'horloge des tests tombe le 1er janvier 1970)
	QNS:DB().winterVeil = "off"
	local icon = UIParent:CreateTexture()
	local netFile, webFile = QNS.CAPTURE_CLIENT_ART.icon.files[1], QNS.CAPTURE_CLIENT_ART.icon.files[2]
	Check("[M211] glyphe du filet : l'icône du jeu INV_Misc_Net_01", QNS.CaptureArtPaint(icon, "icon") == "client"
		and icon.texture == netFile and netFile:find("INV_Misc_Net_01", 1, true) ~= nil)
	Mock.world.textureRefused = { [netFile] = true }
	Check("[M211] icône refusée : une autre icône du jeu", QNS.CaptureArtPaint(icon, "icon") == "client"
		and icon.texture == webFile and webFile:find("^Interface\\Icons\\") ~= nil)
	Mock.world.textureRefused = { [netFile] = true, [webFile] = true }
	Check("[M211] aucune icône : vide, jamais un fichier à nous", QNS.CaptureArtPaint(icon, "icon") == nil and icon.texture == nil)
	Mock.world.textureRefused = nil
	QNS:DB().winterVeil = nil

	-- Ready2Quest : flèches du toast et anneau d'aggro
	local arrow = UIParent:CreateTexture()
	Mock.InstallAtlas(nil)
	Check("[M211] R2Q flèche : sans atlas, vide (1.33.1)", RNS.StatsPaintArrow(arrow, true) == nil and not arrow.clientArrow
		and arrow.texture == nil)
	Mock.InstallAtlas(true)
	Check("[M211] R2Q flèche hausse : bags-greenarrow", RNS.StatsPaintArrow(arrow, true) == "client"
		and arrow.atlas == RNS.STATS_ARROW_ATLAS)
	_G.C_Texture.GetAtlasInfo = function()
		return { file = 555, leftTexCoord = 0.1, rightTexCoord = 0.2, topTexCoord = 0.3, bottomTexCoord = 0.4 }
	end
	local down = UIParent:CreateTexture()
	RNS.StatsPaintArrow(down, false)
	local c = down.texCoord or {}
	Check("[M211] R2Q flèche baisse : la même, retournée (découpe inversée)", down.texture == 555 and c[3] == 0.4 and c[4] == 0.3,
		tostring(c[3]) .. "/" .. tostring(c[4]))
	Check("[M211] R2Q anneau d'aggro retiré (1.33.1)", RNS.AGGRO_RING_ATLAS == nil and RNS.AGGRO_RING_TEXTURE == nil)
	Mock.InstallAtlas(nil)
end

-- 6. Fiche 26 : une seule alerte rouge ----------------------------------------------------
do
	Say("-- 2.11.0 / 1.32.0 : une seule alerte rouge avec les deux add-ons")
	ResetWorld()
	local savedGlobal, savedRings = rawget(_G, "Ready2Quest"), RNS.aggroRings
	_G.Ready2Quest = RNS
	local ring = { verdict = "red", shown = true }
	function ring:IsShown() return self.shown end
	RNS.aggroRings = { plate = ring }
	QNS:DB().companionAggroBlink = "always"
	Check("[M211] anneau rouge de Ready2Quest posé : le compagnon ne clignote pas en plus",
		RNS:AggroDangerShown() and QNS:CompanionAggroDeferred() and not QNS:CompanionAggroAllowed())
	ring.shown = false
	Check("[M211] pas d'anneau rouge : l'alerte du compagnon revient", not QNS:CompanionAggroDeferred() and QNS:CompanionAggroAllowed())
	ring.shown = true
	RNS:DB().aggroEnabled = false
	Check("[M211] aggro de Ready2Quest coupée : le compagnon garde son alerte", not QNS:CompanionAggroDeferred())
	RNS:DB().aggroEnabled = nil
	_G.Ready2Quest = nil
	Check("[M211] Ready2Quest absent : rien ne change", not QNS:CompanionAggroDeferred())
	_G.Ready2Quest, RNS.aggroRings = savedGlobal, savedRings
	QNS:DB().companionAggroBlink = nil
end
