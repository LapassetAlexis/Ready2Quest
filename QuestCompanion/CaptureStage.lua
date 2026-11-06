-- CaptureStage.lua -- la capture en scène (QuestCompanion 1.4.0)
--
-- Comme l'ouverture d'un paquet de cartes : le moment compte autant que le
-- résultat. Au clic sur « Capturer », une scène s'ouvre au centre de l'écran :
--   1. le lancer : le filet (ou l'aide choisie) part du bas, en arc, en
--      tournant, jusqu'au monstre, et s'ouvre ;
--   2. la prise : un filet maillé (1.5.2 : cordes en losanges, corde au bord)
--      tombe sur toute la scène et rebondit ; il se resserre à chaque
--      secousse, la créature se débat dessous ; un halo à la couleur
--      de sa rareté (normal blanc, élite bleu, rare violet, boss orange,
--      brillant doré) pulse derrière ;
--   3. le suspense : une à trois secousses, une pastille par secousse ;
--   4. capturé : éclair blanc, gerbe de losanges à la couleur de la rareté, la
--      créature tourne sur elle-même, la bannière « Capturé ! » grossit puis se
--      pose, avec son nom et sa rareté en losanges (un à cinq) ; le filet se
--      referme sur elle ;
--      échappé : le filet se déchire (les cordes volent et tombent), le
--      monstre file sur le côté et s'efface.
-- Le déroulé (secousses, verdict) reste celui de Capture.lua (CaptureTick) ;
-- ici, on ne fait que le montrer, image par image (OnUpdate de la scène).
-- Réglage : « Capture animée » (page « Au jour le jour »). Coupé, la petite
-- fenêtre fait comme avant.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_THROW_TIME = 0.7       -- s de vol du filet
ns.CAPTURE_STAGE_HOLD = 3.5       -- s de résultat à l'écran (un clic ferme avant)
local STAGE_W, STAGE_H, MODEL = 340, 330, 180
local PARTICLES = 16
local NET = "Interface\\Icons\\Spell_Nature_Web"
-- le filet maillé (1.5.2) : losanges de corde sur toute la scène, une
-- corde épaisse au bord ; le modèle, un peu reculé, tient dedans
local NET_GAP, NET_LINE, NET_RIM = 20, 1.5, 3
local NET_HALF = MODEL / 2 - 6
local ROPE = { 0.86, 0.74, 0.52 }
ns.CAPTURE_STAGE_CAM = 1.2        -- distance de caméra : la créature tient sous le filet
ns.CAPTURE_DRAPE_TIME = 0.3       -- s pour que le filet se pose (rebond)

-- Rareté : couleur et nombre de losanges
local RARITY = {
	trivial   = { color = { 0.62, 0.62, 0.62 }, pips = 1 },
	minus     = { color = { 0.62, 0.62, 0.62 }, pips = 1 },
	normal    = { color = { 0.95, 0.95, 0.95 }, pips = 1 },
	elite     = { color = { 0.00, 0.44, 0.87 }, pips = 2 },
	rare      = { color = { 0.64, 0.21, 0.93 }, pips = 3 },
	rareelite = { color = { 0.64, 0.21, 0.93 }, pips = 4 },
	worldboss = { color = { 1.00, 0.50, 0.00 }, pips = 5 },
}
ns.CAPTURE_RARITY = RARITY

local FR = {
	CAPTURE_STAGE_TITLE = "Capture",
	CAPTURE_STAGE_NEW   = "Nouvelle apparence pour ton compagnon",
	CAPTURE_STAGE_FAIL  = "Il reviendra. Toi aussi.",
	CAPTURE_STAGE_CLOSE = "Clic pour fermer",
	OPT_DAILY_CAPTURE_ANIM = "Capture animée",
}
local EN = {
	CAPTURE_STAGE_TITLE = "Capture",
	CAPTURE_STAGE_NEW   = "New look for your companion",
	CAPTURE_STAGE_FAIL  = "It'll be back. So will you.",
	CAPTURE_STAGE_CLOSE = "Click to close",
	OPT_DAILY_CAPTURE_ANIM = "Animated capture",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_STAGE_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ companionCaptureAnim = true })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present, at = false, 1
	for index, row in ipairs(ns.DAILY_OPTION_ROWS) do
		if row.key == "companionCaptureAnim" then present = true end
		if row.key == "companionCapture" then at = index + 1 end
	end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "companionCaptureAnim", label = "OPT_DAILY_CAPTURE_ANIM", kind = "bool" })
	end
end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Method(obj, name, ...)
	if obj and type(obj[name]) == "function" then return pcall(obj[name], obj, ...) end
	return false
end
local function Place(region, anchor, x, y)
	region:ClearAllPoints()
	region:SetPoint("CENTER", anchor, "CENTER", x, y)
end
local function Clamp01(x) return math.max(0, math.min(1, x)) end
local function EaseOut(x) x = Clamp01(x); return 1 - (1 - x) * (1 - x) end
-- dépasse un peu puis revient (le filet qui retombe)
local function EaseBack(x)
	x = Clamp01(x)
	local k = 1.7
	return 1 + (k + 1) * (x - 1) ^ 3 + k * (x - 1) ^ 2
end

-- Le filet : un cadre carré (centré sur la scène, il grossit avec SetScale)
-- de cordes en diagonale ; chaque corde garde sa place de repos (x, y, rot)
-- pour pouvoir s'envoler quand le filet se déchire
local function NetLine(mesh, color, alpha, width, thick, x, y, rot, index)
	local line = Theme.Solid(mesh, "ARTWORK", color, alpha)
	line:SetSize(math.max(1, width), thick)
	line.x, line.y, line.rot = x, y, rot
	-- déchirure : chaque corde part de son côté, en tournant
	line.vx = ((index * 37) % 11 - 5) * 26
	line.vy = 60 + (index * 17) % 5 * 30
	line.spin = ((index * 13) % 7 - 3) * 1.4
	line:SetPoint("CENTER", mesh, "CENTER", x, y)
	if line.SetRotation then pcall(line.SetRotation, line, rot) end
	return line
end

local function BuildNet(frame)
	local mesh = CreateFrame("Frame", nil, frame)
	mesh:SetSize(MODEL, MODEL)
	mesh:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	mesh:SetFrameLevel((frame:GetFrameLevel() or 1) + 11)
	mesh.lines = {}
	local h, index = NET_HALF, 0
	-- diagonales y = x - c (montantes) et y = c - x (descendantes)
	for _, dir in ipairs({ 1, -1 }) do
		local c = -2 * h + NET_GAP / 2
		while c < 2 * h do
			local len = (2 * h - math.abs(c)) * math.sqrt(2)
			if len > 6 then
				index = index + 1
				local x, y = c / 2, -dir * c / 2
				mesh.lines[#mesh.lines + 1] = NetLine(mesh, ROPE, 0.85, len, NET_LINE, x, y, dir * math.pi / 4, index)
			end
			c = c + NET_GAP
		end
	end
	-- la corde du bord
	local rim = { { 0, h, 2 * h + NET_RIM, 0 }, { 0, -h, 2 * h + NET_RIM, 0 },
		{ -h, 0, 2 * h + NET_RIM, math.pi / 2 }, { h, 0, 2 * h + NET_RIM, math.pi / 2 } }
	for _, r in ipairs(rim) do
		index = index + 1
		mesh.lines[#mesh.lines + 1] = NetLine(mesh, ROPE, 1, r[3], NET_RIM, r[1], r[2], r[4], index)
	end
	mesh:Hide()
	return mesh
end

-- Pose le filet : centre (x, y), échelle, opacité ; tear (s) = déchiré
-- depuis tant de secondes (les cordes s'envolent et tombent)
local function DrawNet(mesh, x, y, scale, alpha, tear)
	if not mesh then return end
	if alpha <= 0 then mesh:Hide(); return end
	mesh:ClearAllPoints()
	mesh:SetPoint("CENTER", mesh:GetParent().scene, "CENTER", x / scale, y / scale)
	mesh:SetScale(math.max(0.05, scale))
	mesh:SetAlpha(Clamp01(alpha))
	for _, line in ipairs(mesh.lines) do
		local lx, ly, rot = line.x, line.y, line.rot
		if tear and tear > 0 then
			lx = lx + line.vx * tear
			ly = ly + line.vy * tear - 520 * tear * tear
			rot = rot + line.spin * tear
		end
		line:ClearAllPoints()
		line:SetPoint("CENTER", mesh, "CENTER", lx, ly)
		if line.SetRotation then pcall(line.SetRotation, line, rot) end
	end
	mesh.tear = tear
	mesh:Show()
end
ns.CaptureDrawNet = DrawNet

function ns:CaptureStageOn()
	return self:DB().companionCaptureAnim ~= false and Theme ~= nil and Theme.CreateToast ~= nil
end

function ns:CaptureRarity(target)
	if target and target.shiny then
		return { color = Theme.GOLD_LIGHT or { 0.96, 0.78, 0.49 }, pips = (RARITY[target.class] or RARITY.normal).pips }
	end
	return RARITY[(target and target.class) or "normal"] or RARITY.normal
end

local function PlayKit(name)
	local kit, play = G("SOUNDKIT"), G("PlaySound")
	if type(kit) == "table" and kit[name] and type(play) == "function" then pcall(play, kit[name]) end
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
function ns:EnsureCaptureStage()
	if self.captureStage then return self.captureStage end
	local frame = Theme.CreateToast(UIParent, STAGE_W, STAGE_H, { strata = "DIALOG" })
	if not frame then return nil end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	frame:EnableMouse(true)
	-- un clic, une fois le verdict tombé : on ferme
	frame:SetScript("OnMouseUp", function()
		local rolling = ns.captureState and ns.captureState.rolling
		if rolling and rolling.result then rolling.closeAt = Clock() end
	end)

	-- halo de rareté (derrière tout) et filet haut à sa couleur
	frame.glow = Theme.Solid(frame, "BACKGROUND", { 1, 1, 1 }, 0.15)
	frame.glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	frame.glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.topBar = Theme.Solid(frame, "BORDER", { 1, 1, 1 }, 1)
	frame.topBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	frame.topBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
	frame.topBar:SetHeight(3)

	frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
	frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_STAGE_TITLE) or L.CAPTURE_STAGE_TITLE)

	-- la scène : un carré centré où vivent modèle, filet, éclair, losanges
	frame.scene = CreateFrame("Frame", nil, frame)
	frame.scene:SetSize(MODEL, MODEL)
	frame.scene:SetPoint("TOP", frame, "TOP", 0, -34)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, frame.scene)
	if ok and model then
		model:SetSize(MODEL, MODEL)
		model:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
		frame.model = model
	end
	frame.fallback = frame.scene:CreateTexture(nil, "ARTWORK")
	frame.fallback:SetSize(72, 72)
	frame.fallback:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	frame.fallback:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
	frame.fallback:Hide()

	-- le filet : un calque au-dessus du modèle (cadre enfant : passe devant le 3D)
	frame.netLayer = CreateFrame("Frame", nil, frame)
	frame.netLayer:SetAllPoints(frame.scene)
	frame.netLayer:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
	frame.net = frame.netLayer:CreateTexture(nil, "OVERLAY")
	frame.net:SetTexture(NET)
	frame.net:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.net:SetSize(48, 48)
	frame.mesh = BuildNet(frame)
	frame.flash = Theme.Solid(frame.netLayer, "OVERLAY", { 1, 1, 1 }, 0)
	frame.flash:SetAllPoints(frame.scene)
	frame.particles = {}
	for index = 1, PARTICLES do
		local p = Theme.CreateDiamond and Theme.CreateDiamond(frame.netLayer, 8) or frame.netLayer:CreateTexture(nil, "OVERLAY")
		p:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
		p.angle = (index / PARTICLES) * math.pi * 2 + (index % 2) * 0.2
		p.reach = 110 + (index % 3) * 22
		p:Hide()
		frame.particles[index] = p
	end

	-- bannière (cadre à part : elle grossit avec SetScale), nom, rareté, pied
	frame.banner = CreateFrame("Frame", nil, frame)
	frame.banner:SetSize(STAGE_W, 34)
	frame.banner:SetPoint("TOP", frame.scene, "BOTTOM", 0, -6)
	frame.banner:SetFrameLevel((frame:GetFrameLevel() or 1) + 12)
	frame.bannerText = Theme.Text(frame.banner, Theme.F_DISPLAY or Theme.F_TITLE, Theme.PARCHMENT)
	frame.bannerText:SetPoint("CENTER", frame.banner, "CENTER", 0, 0)
	frame.name = Theme.Text(frame, Theme.F_HEADING or Theme.F_BODY, Theme.PARCHMENT)
	frame.name:SetPoint("TOP", frame.banner, "BOTTOM", 0, -4)
	frame.name:SetWidth(STAGE_W - 24)
	frame.name:SetJustifyH("CENTER")
	frame.pips = {}
	for index = 1, 5 do
		local pip = Theme.CreateDiamond and Theme.CreateDiamond(frame, 9) or frame:CreateTexture(nil, "OVERLAY")
		frame.pips[index] = pip
	end
	frame.footer = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
	frame.footer:SetWidth(STAGE_W - 24)
	frame.footer:SetJustifyH("CENTER")

	frame:SetScript("OnUpdate", function()
		local done, err = pcall(ns.CaptureStageUpdate, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("capture:stage", err) end
	end)
	frame:Hide()
	self.captureStage = frame
	return frame
end

-- ---------------------------------------------------------------------------
-- Ouvrir, fermer
-- ---------------------------------------------------------------------------
function ns:CaptureShowStage(rolling)
	local frame = self:EnsureCaptureStage()
	if not (frame and rolling) then return nil end
	local target = rolling.target
	local rarity = self:CaptureRarity(target)
	frame.rolling = rolling
	frame.rarity = rarity
	local c = rarity.color
	frame.topBar:SetVertexColor(c[1], c[2], c[3], 1)
	frame.glow:SetVertexColor(c[1], c[2], c[3], 0.12)
	local shown = false
	if frame.model then
		frame.model:Show()
		shown = Method(frame.model, "SetCreature", target.npcID)
		Method(frame.model, "SetCamDistanceScale", ns.CAPTURE_STAGE_CAM)
		-- une brillante : sous sa lumière dorée (1.6.0)
		if ns.ModelShinyLight then ns.ModelShinyLight(frame.model, target.shiny) end
		Method(frame.model, "SetFacing", 0)
		Method(frame.model, "SetAlpha", 1)
		if not shown then frame.model:Hide() end
	end
	if frame.model then Place(frame.model, frame.scene, 0, 0) end
	Place(frame.fallback, frame.scene, 0, 0)
	frame.fallback:SetAlpha(1)
	if shown then frame.fallback:Hide() else frame.fallback:Show() end
	frame.hasModel = shown
	-- le filet : l'aide choisie (son icône), sinon une toile
	local aid
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == rolling.aid then aid = def end end
	frame.net:SetTexture(aid and aid.icon or NET)
	frame.net:Show()
	DrawNet(frame.mesh, 0, 0, 1, 0)
	frame.bannerText:SetText("")
	frame.name:SetText(target.shiny and self:F("CAPTURE_SHINY_TAG", target.name) or target.name)
	frame.name:SetTextColor(c[1], c[2], c[3])
	-- losanges de rareté, centrés sous le nom
	local gap = 13
	for index, pip in ipairs(frame.pips) do
		pip:ClearAllPoints()
		if index <= rarity.pips then
			pip:SetPoint("TOP", frame.name, "BOTTOM", (index - (rarity.pips + 1) / 2) * gap, -6)
			pip:SetVertexColor(c[1], c[2], c[3], 1)
			pip:Show()
		else
			pip:Hide()
		end
	end
	frame.footer:SetText(L.CAPTURE_SHAKING)
	frame.played = nil
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	self:CaptureStageUpdate(Clock())
	return frame
end

function ns:CaptureHideStage()
	local frame = self.captureStage
	if frame then
		frame.rolling = nil
		frame:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- Une image : tout se déduit de l'horloge et de l'état du lancer
-- ---------------------------------------------------------------------------

function ns:CaptureStageUpdate(now)
	local frame = self.captureStage
	local rolling = frame and frame.rolling
	if not rolling then return nil end
	local c = frame.rarity.color
	local t = now - (rolling.start or now)
	local throw = ns.CAPTURE_THROW_TIME
	local phase

	if not rolling.result then
		frame.bannerText:SetText("")
		if t < throw then
			-- 1. le lancer : du bas de la scène au centre, en arc, en tournant
			phase = "throw"
			local p = Clamp01(t / throw)
			local y = -150 + 150 * p + 70 * math.sin(math.pi * p)
			Place(frame.net, frame.scene, 0, y)
			local size = 40 + 24 * p
			frame.net:SetSize(size, size)
			Method(frame.net, "SetRotation", p * math.pi * 4)
			-- le paquet s'ouvre en fin de course
			frame.net:SetAlpha(1 - Clamp01((p - 0.8) / 0.2))
			DrawNet(frame.mesh, 0, y, 0.25 + 0.35 * Clamp01((p - 0.8) / 0.2), Clamp01((p - 0.8) / 0.2))
			if frame.model then Method(frame.model, "SetAlpha", 1) end
			frame.flash:SetAlpha(0)
		else
			-- 2-3. la prise, puis les secousses
			phase = "shake"
			local since = t - throw
			local step = ns.CAPTURE_SHAKE_STEP
			local inStep = (since % step) / step
			-- une secousse au début de chaque pas, amortie
			local wobble = inStep < 0.5 and math.sin(inStep * math.pi * 6) * 9 * (1 - inStep * 2) or 0
			Place(frame.scene, frame, wobble, -34 - MODEL / 2 + STAGE_H / 2)
			frame.net:SetAlpha(0)
			-- il se pose : tombe d'un peu plus haut, plus grand, et rebondit ;
			-- puis se resserre à chaque secousse
			local drape = Clamp01(since / ns.CAPTURE_DRAPE_TIME)
			local squeeze = inStep < 0.5 and 0.05 * math.sin(inStep * math.pi * 2) or 0
			local scale = 0.6 + 0.4 * EaseBack(drape) - squeeze - 0.01 * rolling.done
			DrawNet(frame.mesh, 0, 40 * (1 - EaseOut(drape)), scale, 1)
			-- la créature se débat dessous
			if frame.model then
				Method(frame.model, "SetAlpha", 0.8)
				Method(frame.model, "SetFacing", wobble * 0.06)
			end
			-- éclair bref à l'impact
			frame.flash:SetVertexColor(1, 1, 1, 1)
			frame.flash:SetAlpha(math.max(0, 0.7 - since * 3))
			frame.footer:SetText(L.CAPTURE_SHAKING .. " " .. string.rep("• ", math.min(rolling.done + 1, 3)))
		end
		-- le halo pulse, de plus en plus vite
		frame.glow:SetVertexColor(c[1], c[2], c[3], 0.12 + 0.10 * math.abs(math.sin(t * (3 + rolling.done * 2))))
		for _, p in ipairs(frame.particles) do p:Hide() end
		frame.banner:SetScale(1)
		return phase
	end

	local r = now - (rolling.resultAt or now)
	Place(frame.scene, frame, 0, -34 - MODEL / 2 + STAGE_H / 2)
	frame.footer:SetText(r > 1.2 and L.CAPTURE_STAGE_CLOSE
		or (rolling.result == "ok" and L.CAPTURE_STAGE_NEW or L.CAPTURE_STAGE_FAIL))
	-- bannière : grossit puis se pose
	local pop = Clamp01(r / 0.25)
	frame.banner:SetScale(1.6 - 0.6 * pop)
	if rolling.result == "ok" then
		phase = "ok"
		if not frame.played then frame.played = true; PlayKit("UI_EPICLOOT_TOAST") end
		frame.bannerText:SetText(L.CAPTURE_GOT)
		frame.bannerText:SetTextColor(c[1], c[2], c[3])
		frame.net:SetAlpha(0)
		-- le filet se referme sur elle et s'efface dans l'éclair
		local close = Clamp01(r / 0.35)
		DrawNet(frame.mesh, 0, 0, 1 - 0.45 * EaseOut(close), 1 - close)
		Place(frame.fallback, frame.scene, 0, 0)
		frame.fallback:SetAlpha(1)
		frame.flash:SetVertexColor(1, 1, 1, 1)
		frame.flash:SetAlpha(math.max(0, 1 - r / 0.4))
		if frame.model then
			Method(frame.model, "SetAlpha", 1)
			-- un tour sur elle-même, qui ralentit
			Method(frame.model, "SetFacing", EaseOut(r / 1.2) * math.pi * 2)
		end
		-- la gerbe : les losanges filent du centre et s'éteignent
		local burst = Clamp01(r / 0.9)
		for _, p in ipairs(frame.particles) do
			if burst < 1 then
				local d = p.reach * EaseOut(burst)
				Place(p, frame.scene, math.cos(p.angle) * d, math.sin(p.angle) * d)
				p:SetVertexColor(c[1], c[2], c[3], 1 - burst)
				p:Show()
			else
				p:Hide()
			end
		end
		frame.glow:SetVertexColor(c[1], c[2], c[3], 0.12 + 0.25 * math.max(0, 1 - r))
	else
		phase = "fail"
		if not frame.played then frame.played = true; PlayKit("IG_QUEST_LOG_ABANDON_QUEST") end
		frame.bannerText:SetText(L.CAPTURE_FLED)
		frame.bannerText:SetTextColor(Theme.RED[1], Theme.RED[2], Theme.RED[3])
		-- le filet tombe, le monstre file à droite et s'efface
		frame.net:SetAlpha(0)
		-- le filet se déchire : les cordes volent en tous sens et tombent
		DrawNet(frame.mesh, 0, 0, 1, 1 - Clamp01(r / 0.9), r)
		frame.flash:SetAlpha(0)
		local run = EaseOut(r / 0.8)
		if frame.model then
			Method(frame.model, "SetFacing", -math.pi / 2)
			Method(frame.model, "SetAlpha", math.max(0, 1 - run))
			Place(frame.model, frame.scene, run * 140, 0)
		end
		Place(frame.fallback, frame.scene, run * 140, 0)
		frame.fallback:SetAlpha(math.max(0, 1 - run))
		for _, p in ipairs(frame.particles) do p:Hide() end
		frame.glow:SetVertexColor(Theme.RED[1], Theme.RED[2], Theme.RED[3], 0.12 * math.max(0, 1 - r))
	end
	return phase
end

if ns.Mark then ns.Mark("CaptureStage") end
