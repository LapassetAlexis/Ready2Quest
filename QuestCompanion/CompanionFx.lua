-- CompanionFx.lua -- effets du compagnon à l'écran (QuestCompanion)
--
-- Les animations des créatures du jeu ne sont pas toutes jouables (un
-- dragonnet n'a pas forcément d'animation de joie). Les réactions passent
-- donc d'abord par des effets sur son cadre, qui marchent toujours :
--   bounce   petit rebond (niveau, évolution)
--   shake    tremblement (élite ou rare repéré)
--   float    flotte doucement quand il est heureux (continu)
--   hearts   petits cœurs (caresse)
--   crumbs   miettes (repas)
--   alert    « ! » au-dessus de lui (conseil de route)
--   zzz      « Zzz » qui montent (il dort au camp)
-- Les vraies animations de la créature s'y ajoutent quand elle les joue :
-- /qc compagnon anim les fait défiler, et « /qc compagnon anim non <nom> »
-- retient celles qui ne bougent pas (par apparence), qu'on ne rejoue plus.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	COMP_ANIM_TEST       = "Animation %d/%d : %s. Si rien ne bouge : /qc compagnon anim non %s",
	COMP_ANIM_DONE       = "Fin du défilé. Animations coupées pour cette apparence : %s.",
	COMP_ANIM_NONE       = "aucune",
	COMP_ANIM_OFF        = "Animation « %s » coupée pour cette apparence (les effets restent).",
	COMP_ANIM_ON         = "Animation « %s » de nouveau jouée pour cette apparence.",
	COMP_ANIM_UNKNOWN    = "Animation inconnue. Noms : %s.",
}
local EN = {
	COMP_ANIM_TEST       = "Animation %d/%d: %s. If nothing moves: /qc compagnon anim non %s",
	COMP_ANIM_DONE       = "End of the show. Animations turned off for this appearance: %s.",
	COMP_ANIM_NONE       = "none",
	COMP_ANIM_OFF        = "Animation \"%s\" turned off for this appearance (effects stay).",
	COMP_ANIM_ON         = "Animation \"%s\" played again for this appearance.",
	COMP_ANIM_UNKNOWN    = "Unknown animation. Names: %s.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMPANION_FX_STRINGS = { fr = FR, en = EN } end

-- animations de créature essayées par le défilé (identifiants du client)
ns.COMPANION_ANIMS.walk = ns.COMPANION_ANIMS.walk or 4
ns.COMPANION_ANIMS.run = ns.COMPANION_ANIMS.run or 5
ns.COMPANION_ANIMS.attack = ns.COMPANION_ANIMS.attack or 16
ns.COMPANION_ANIM_ORDER = { "idle", "walk", "run", "attack", "talk", "cheer", "dance", "sit", "sleep" }
ns.COMPANION_ANIM_STEP = 3

-- durée, nombre de particules, couleur
local FX = {
	bounce = { duration = 0.6 },
	shake  = { duration = 0.6 },
	hearts = { duration = 1.6, count = 4, color = { 1.0, 0.45, 0.65 } },
	crumbs = { duration = 1.2, count = 5, color = { 0.78, 0.58, 0.32 } },
	alert  = { duration = 2.0 },
	zzz    = { duration = 2.4, count = 2 },
}
ns.COMPANION_FX = FX

local function Clock() return (ns.Now and ns.Now()) or 0 end

-- Décalage du modèle (ou de la boussole de repli) dans son cadre
-- appelé à chaque image : rien à toucher si le décalage n'a pas bougé
-- (au dixième de pixel), et pas de nouvelle table (1.6.1)
local function Offset(frame, dx, dy)
	dx, dy = math.floor(dx * 10 + 0.5) / 10, math.floor(dy * 10 + 0.5) / 10
	local last = frame.fxOffset
	if last and last[1] == dx and last[2] == dy then return end
	-- la place du modèle dépend du style (frame.modelBase, 2.8.2)
	if frame.model and frame.model.SetPoint then ns:CompanionPlaceModel(dx, dy) end
	if frame.fallback and frame.fallback.SetPoint then
		frame.fallback:ClearAllPoints()
		frame.fallback:SetPoint("TOP", frame, "TOP", dx, -14 + dy)
	end
	if last then last[1], last[2] = dx, dy else frame.fxOffset = { dx, dy } end
end

local function State(self)
	local state = self.companionFx
	if not state then
		state = { particles = {}, pool = {} }
		self.companionFx = state
	end
	return state
end

local function Particle(self, frame, kind)
	local state = State(self)
	local p = table.remove(state.pool)
	if not p then
		p = {}
		p.dot = Theme.CreateDiamond and Theme.CreateDiamond(frame, 7) or frame:CreateTexture(nil, "OVERLAY")
		p.text = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	end
	p.kind = kind
	state.particles[#state.particles + 1] = p
	return p
end

-- Lance un effet ; renvoie true s'il est parti
function ns:CompanionFx(kind)
	local frame = self.companionFrame
	local def = FX[kind]
	if not frame or not def or not (frame.IsShown and frame:IsShown()) then return false end
	local now, state = Clock(), State(self)
	if kind == "bounce" or kind == "shake" then
		state.motion = { kind = kind, at = now, untilAt = now + def.duration }
	elseif kind == "alert" then
		if not frame.alert then
			frame.alert = frame:CreateTexture(nil, "OVERLAY")
			frame.alert:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
			frame.alert:SetSize(18, 18)
			frame.alert:SetPoint("BOTTOM", frame, "TOP", 0, -6)
		end
		frame.alert:Show()
		state.alertUntil = now + def.duration
	else
		for index = 1, def.count or 1 do
			local p = Particle(self, frame, kind)
			p.at, p.untilAt = now, now + def.duration
			p.x = (index - (def.count + 1) / 2) * 12
			p.y = -20
			p.rise = 26 + index * 4
			local region = (kind == "zzz") and p.text or p.dot
			local other = (kind == "zzz") and p.dot or p.text
			if other.Hide then other:Hide() end
			if kind == "zzz" then
				p.text:SetText(index == 1 and "z" or "Z")
				p.text:SetTextColor(0.75, 0.82, 0.95)
			elseif def.color and p.dot.SetVertexColor then
				p.dot:SetVertexColor(def.color[1], def.color[2], def.color[3], 1)
			end
			p.region = region
			region:ClearAllPoints()
			region:SetPoint("CENTER", frame, "CENTER", p.x, p.y)
			region:SetAlpha(1)
			region:Show()
		end
	end
	return true
end

-- Une image : mouvements, particules, fins d'effet, flottement heureux
function ns:CompanionFxUpdate(now)
	local frame = self.companionFrame
	if not frame then return end
	now = now or Clock()
	local state = State(self)
	local dx, dy = 0, 0
	local motion = state.motion
	if motion then
		local t = now - motion.at
		if now >= motion.untilAt then
			state.motion = nil
		elseif motion.kind == "bounce" then
			dy = math.abs(math.sin(t / FX.bounce.duration * math.pi * 2)) * 10
		else
			dx = math.sin(t * 60) * 3
		end
	elseif self.CompanionIsHappy and self:CompanionIsHappy() then
		dy = math.sin(now * 1.6) * 2           -- heureux : il flotte
	end
	-- son caractère : effets plus ou moins amples (Personality.lua)
	local scale = self.CompanionFxIntensity and self:CompanionFxIntensity() or 1
	Offset(frame, dx * scale, dy * scale)
	-- particules : montent et s'effacent (tassées sur place : pas de table
	-- neuve à chaque image)
	local particles = state.particles
	local kept = 0
	for index = 1, #particles do
		local p = particles[index]
		if now >= p.untilAt then
			if p.region then p.region:Hide() end
			state.pool[#state.pool + 1] = p
		else
			local ratio = (now - p.at) / (p.untilAt - p.at)
			p.region:ClearAllPoints()
			p.region:SetPoint("CENTER", frame, "CENTER", p.x, p.y + p.rise * ratio)
			p.region:SetAlpha(1 - ratio)
			kept = kept + 1
			particles[kept] = p
		end
	end
	for index = #particles, kept + 1, -1 do particles[index] = nil end
	if frame.alert and state.alertUntil and now >= state.alertUntil then
		frame.alert:Hide()
		state.alertUntil = nil
	end
end

-- ---------------------------------------------------------------------------
-- Animations de la créature : celles qu'elle ne joue pas sont retenues
-- (par apparence) et remplacées par l'animation immobile
-- ---------------------------------------------------------------------------
function ns:CompanionAnimOff()
	local data = self:CompanionData()
	if type(data.animOff) ~= "table" then data.animOff = {} end
	local app = tostring(data.appearance)
	if type(data.animOff[app]) ~= "table" then data.animOff[app] = {} end
	return data.animOff[app]
end

function ns:CompanionAnimSupported(name)
	return name == "idle" or not self:CompanionAnimOff()[name]
end

local Animate = ns.CompanionAnimate
function ns:CompanionAnimate(name, duration)
	if name and not self:CompanionAnimSupported(name) then
		-- la créature ne la joue pas : immobile, mais la durée compte (l'effet suffit)
		Animate(self, "idle", duration)
		local frame = self.companionFrame
		if frame then frame.animation = name end
		return
	end
	return Animate(self, name, duration)
end

-- Défilé des animations : une toutes les COMPANION_ANIM_STEP secondes
function ns:CompanionAnimTest()
	self.companionAnimTest = { index = 0, nextAt = 0 }
	self:CompanionUpdateVisibility()
	self:CompanionAnimTestStep(Clock())
end

function ns:CompanionAnimTestStep(now)
	local test = self.companionAnimTest
	if not test or now < test.nextAt then return end
	test.index = test.index + 1
	local order = ns.COMPANION_ANIM_ORDER
	local name = order[test.index]
	if not name then
		self.companionAnimTest = nil
		local off = {}
		for key, value in pairs(self:CompanionAnimOff()) do if value then off[#off + 1] = key end end
		table.sort(off)
		self:Print(self:F("COMP_ANIM_DONE", #off > 0 and table.concat(off, ", ") or L.COMP_ANIM_NONE))
		Animate(self)
		return
	end
	test.nextAt = now + ns.COMPANION_ANIM_STEP
	-- le défilé joue tout, même ce qui a été coupé : on peut se raviser
	Animate(self, name, ns.COMPANION_ANIM_STEP)
	self:Print(self:F("COMP_ANIM_TEST", test.index, #order, name, name))
end

-- /qc compagnon anim [non|oui <nom>]
function ns:CompanionAnimCommand(arg)
	local what, name = tostring(arg or ""):match("^%s*(%S*)%s*(%S*)")
	what, name = (what or ""):lower(), (name or ""):lower()
	if what == "" then return self:CompanionAnimTest() end
	if (what == "non" or what == "no" or what == "off" or what == "oui" or what == "yes" or what == "on")
		and ns.COMPANION_ANIMS[name] and name ~= "idle" then
		local off = what == "non" or what == "no" or what == "off"
		self:CompanionAnimOff()[name] = off or nil
		return self:Print(self:F(off and "COMP_ANIM_OFF" or "COMP_ANIM_ON", name))
	end
	return self:Print(self:F("COMP_ANIM_UNKNOWN", table.concat(ns.COMPANION_ANIM_ORDER, ", ")))
end

local Command = ns.CompanionCommand
function ns:CompanionCommand(rest)
	local sub, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	if (sub or ""):lower() == "anim" and self.CompanionOn() then return self:CompanionAnimCommand(arg) end
	return Command(self, rest)
end

-- ---------------------------------------------------------------------------
-- Déclencheurs : sur les moments qui existent déjà
-- ---------------------------------------------------------------------------
local function Wrap(name, after)
	local original = ns[name]
	if type(original) ~= "function" then return end
	ns[name] = function(self, ...)
		local a, b, c = original(self, ...)
		local ok, err = pcall(after, self, a, ...)
		if not ok and self.RecordError then self:RecordError("fx:" .. name, err) end
		return a, b, c
	end
end

-- ---------------------------------------------------------------------------
-- Animations des grands moments : seulement quand le modèle sait jouer une
-- animation (PlayerModel:SetAnimation). Sans lui (boussole de repli, client
-- sans la méthode), rien ne change. Le retour au repos passe par l'horloge
-- du compagnon (companionAnimUntil, Companion.lua).
-- ---------------------------------------------------------------------------
-- réservoir -> { animation, durée } ; les autres bulles : « talk »
ns.COMPANION_MOMENT_ANIMS = {
	MISSION_DONE = { "cheer", 2.5 }, MISSION_ALL = { "cheer", 2.5 },
	SHINY_KILLED = { "dance", 3 }, TREAT_GOLDEN = { "dance", 3 }, INN_FULL = { "dance", 3 },
	IDLE = { "sit", 8 },
}
ns.COMPANION_TALK_TIME = 1.5
-- une animation en cours n'est remplacée que par une plus importante
local MOMENT_RANK = { talk = 1, sit = 2, cheer = 3, dance = 4 }

function ns:CompanionModelAnimates()
	local frame = self.companionFrame
	local model = frame and not frame.usesFallback and frame.model
	return model ~= nil and model ~= false and type(model.SetAnimation) == "function"
end

-- Joue `name` pendant `duration` s, puis l'animation de l'humeur revient.
-- Renvoie true si l'animation part.
function ns:CompanionMoment(name, duration)
	if not self:CompanionModelAnimates() or self.companionAnimTest then return false end
	local frame = self.companionFrame
	-- il dort : on ne le fait pas parler en dormant (la caresse le réveille d'abord)
	if frame.animation == "sleep" or self:CompanionData().sleepy then return false end
	local busy = self.companionAnimUntil and Clock() < self.companionAnimUntil
	if busy and (MOMENT_RANK[frame.animation] or 3) > (MOMENT_RANK[name] or 0) then return false end
	self:CompanionAnimate(name, duration)
	return true
end

Wrap("CompanionPet", function(self) self:CompanionFx("hearts") end)
Wrap("CompanionOnLevel", function(self)
	self:CompanionFx("bounce")
	self:CompanionMoment("cheer", 2.5)
end)
Wrap("CompanionSay", function(self, said, pool, opts)
	if not said then return end
	local moment = ns.COMPANION_MOMENT_ANIMS[pool]
	if moment then
		self:CompanionMoment(moment[1], moment[2])
	else
		self:CompanionMoment("talk", ns.COMPANION_TALK_TIME)
	end
	if pool == "ADVICE_ELITE" or pool == "ADVICE_RARE" then
		self:CompanionFx("shake")
		self:CompanionFx("alert")
	elseif type(opts) == "table" and opts.category == "advice" then
		self:CompanionFx("alert")
	elseif pool == "EVOLVE" then
		self:CompanionFx("bounce")
	end
end)
-- repas : des miettes au début, puis de temps en temps tant qu'il mange
Wrap("CompanionCheckAuras", function(self)
	local now = Clock()
	if self.companionEating and (not self.companionCrumbsAt or now - self.companionCrumbsAt >= 4) then
		self.companionCrumbsAt = now
		self:CompanionFx("crumbs")
	end
end)

-- image par image ; et des « Zzz » de temps en temps quand il dort
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	frame:SetScript("OnUpdate", function()
		-- 2.8.1 : compagnon absent ou caché (module coupé, masqué), rien à
		-- animer ni à mesurer à chaque image ; ses effets reprennent à
		-- l'affichage, là où l'horloge en est
		local f = ns.companionFrame
		if not (f and f:IsShown()) and not ns.companionAnimTest then return end
		local now = Clock()
		local done, err = pcall(ns.CompanionFxUpdate, ns, now)
		if not done then ns:RecordError("fx:update", err) end
		if ns.companionAnimTest then pcall(ns.CompanionAnimTestStep, ns, now) end
		if f and f.animation == "sleep" and (not ns.companionZzzAt or now - ns.companionZzzAt >= 3) then
			ns.companionZzzAt = now
			ns:CompanionFx("zzz")
		end
	end)
	ns.companionFxFrame = frame
end

-- ---------------------------------------------------------------------------
-- 2.9.0 (idée d'Enimag) : plusieurs monstres sur toi, le cadre du compagnon
-- clignote en rouge. Compté sur les barres de nom : un ennemi dont la cible
-- est toi. Valeurs secrètes ou API absente : rien ne clignote.
-- ---------------------------------------------------------------------------
ns.COMPANION_AGGRO_MIN = 2          -- monstres sur toi pour clignoter
ns.COMPANION_AGGRO_POLL = 0.5       -- s entre deux comptes
ns.COMPANION_AGGRO_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
if ns.RegisterDefaults then ns.RegisterDefaults({ companionAggroBlink = true }) end

local function Plain(v) return ns.Plain and ns.Plain(v) or v end
local function SafeCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return Plain(a) end
	return nil
end

-- « nameplate3 » -> « nameplate3target », fait une fois par jeton (le compte
-- passe deux fois par seconde sur chaque barre)
local TARGET_OF = setmetatable({}, { __index = function(t, unit)
	local token = unit .. "target"
	t[unit] = token
	return token
end })

function ns:CompanionAggroCount()
	local api = rawget(_G, "C_NamePlate")
	if type(api) ~= "table" or type(api.GetNamePlates) ~= "function" then return 0 end
	local ok, plates = pcall(api.GetNamePlates)
	if not ok or type(plates) ~= "table" then return 0 end
	local count = 0
	for _, plate in ipairs(plates) do
		local unit = type(plate) == "table" and Plain(plate.namePlateUnitToken)
		if type(unit) == "string" and SafeCall(rawget(_G, "UnitCanAttack"), "player", unit) == true
			and SafeCall(rawget(_G, "UnitIsDead"), unit) ~= true
			and SafeCall(rawget(_G, "UnitIsUnit"), TARGET_OF[unit], "player") == true then
			count = count + 1
		end
	end
	return count
end

function ns:CompanionAggroUpdate(now)
	local frame = self.companionFrame
	if not frame then return false end
	now = now or Clock()
	local state = State(self)
	if not state.aggroAt or now < state.aggroAt or now - state.aggroAt >= ns.COMPANION_AGGRO_POLL then
		state.aggroAt = now
		local on = self:DB().companionAggroBlink ~= false and (frame.IsShown and frame:IsShown())
			and self:CompanionAggroCount() >= ns.COMPANION_AGGRO_MIN
		state.aggroOn = on and true or false
	end
	if state.aggroOn then
		if not frame.danger then
			frame.danger = frame:CreateTexture(nil, "OVERLAY")
			frame.danger:SetTexture(ns.COMPANION_AGGRO_TEXTURE)
			if frame.danger.SetBlendMode then frame.danger:SetBlendMode("ADD") end
			frame.danger:SetPoint("TOPLEFT", frame, "TOPLEFT", -14, 14)
			frame.danger:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 14, -14)
			frame.danger:SetVertexColor(1, 0.12, 0.08, 1)
		end
		-- battement : deux par seconde
		frame.danger:SetAlpha(0.35 + 0.65 * math.abs(math.sin(now * math.pi * 2)))
		frame.danger:Show()
	elseif frame.danger and frame.danger:IsShown() then
		frame.danger:Hide()      -- chaque image au repos : seulement s'il est affiché
	end
	return state.aggroOn
end

do
	local ok, ticker = pcall(CreateFrame, "Frame")
	if ok and ticker then
		ticker:SetScript("OnUpdate", function()
			if ns.companionFrame then pcall(ns.CompanionAggroUpdate, ns) end
		end)
		ns.companionAggroTicker = ticker
	end
end

if ns.Mark then ns.Mark("CompanionFx") end
