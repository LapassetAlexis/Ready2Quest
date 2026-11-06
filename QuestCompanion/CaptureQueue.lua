-- CaptureQueue.lua -- Lot 1 : bouton filet, file d'attente des captures, étoiles des spécimens (QuestCompanion 2.0)
--
-- Retour des joueurs : la fenêtre « Capturer ? » qui s'ouvrait à chaque coup
-- fatal gênait (en plein pack, elle se remplaçait sans cesse). Désormais :
--   * chaque monstre abattu qui VAUT LE COUP rejoint une file d'attente :
--     espèce (ou version) pas encore capturée, brillante, ou spécimen qui
--     pourrait battre le tien (moins de 3 étoiles) ;
--   * chacun y reste CAPTURE_QUEUE_TIME secondes, comptées à partir de la FIN
--     du combat (en plein pack, rien ne s'efface) ;
--   * un petit bouton filet sur le cadre du compagnon, visible seulement si la
--     file n'est pas vide, avec un compteur ; doré et scintillant si une
--     brillante attend ;
--   * clic : capture du meilleur candidat (brillante > espèce nouvelle > plus
--     rare > amélioration d'étoiles), la scène de capture se joue
--     (CaptureStage.lua) ; clic droit : la liste (choisir, aides, tout ignorer).
-- Étoiles : chaque capture tire une qualité de 1 à 3 étoiles (3 la plus
-- rare, CAPTURE_STAR_ODDS). On peut recapturer pour tenter mieux : le
-- meilleur spécimen est gardé (entry.stars, entry.shinyStars).
-- Le déroulé d'un essai reste celui de Capture.lua (CaptureThrow, CaptureTick,
-- CaptureResolve) : ce fichier choisit la cible et habille le reste.
-- Réglage : page « Au jour le jour » (« Capturer les monstres abattus »).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_QUEUE_TIME = 30        -- s par candidat, à partir de la fin du combat
ns.CAPTURE_QUEUE_MAX = 12         -- au-delà, les moins intéressants sortent
ns.CAPTURE_STAR_MAX = 3
-- tirage de la qualité (en %) : 1, 2, 3 étoiles. Trois étoiles : une
-- capture sur dix en moyenne, de quoi donner envie de recapturer sans
-- en faire une corvée.
ns.CAPTURE_STAR_ODDS = { 60, 30, 10 }
-- l'étoile (icône de cible du jeu, teintée) : pleine dorée, vide grise
ns.CAPTURE_STAR_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local NET_ICON = "Interface\\Icons\\Spell_Nature_Web"
local NET_SIZE = 22
local LIST_W, LIST_ROW_H, LIST_ROWS = 300, 24, 6

local RANK_ORDER = { trivial = 0, minus = 0, normal = 1, elite = 2, rare = 3, rareelite = 4, worldboss = 5 }

local FR = {
	CAPTURE_Q_TITLE        = "À capturer",
	CAPTURE_Q_COUNT        = "Filet : %d à capturer",
	CAPTURE_Q_REASON_shiny = "Brillante !",
	CAPTURE_Q_REASON_new   = "Pas encore capturée",
	CAPTURE_Q_REASON_stars = "Peut battre ton spécimen %s",
	CAPTURE_Q_WAIT         = "après le combat",
	CAPTURE_Q_LEFT         = "%d s",
	CAPTURE_Q_CLICK        = "Clic : capturer %s",
	CAPTURE_Q_RIGHT        = "Clic droit : la liste (choisir, aides, tout ignorer)",
	CAPTURE_Q_IGNORE       = "Tout ignorer",
	CAPTURE_Q_EMPTY        = "Rien à capturer pour l'instant.",
	CAPTURE_Q_LIST_HINT    = "Clic sur une ligne : la capturer. L'aide choisie sert au prochain essai.",
	CAPTURE_Q_AID          = "Aide : %s",
	CAPTURE_STARS_LABEL    = "Qualité : %s",
	CAPTURE_MSG_STARS      = "%s : %s.",
	CAPTURE_MSG_STARS_BEST = "%s : %s, ton meilleur spécimen !",
	CAPTURE_MSG_STARS_KEPT = "%s : %s. Ton spécimen à %d étoiles reste.",
	CAPTURE_STAGE_BEST     = "Meilleur spécimen !",
	CAPTURE_STAGE_KEPT     = "Le tien garde ses %d étoiles",
}
local EN = {
	CAPTURE_Q_TITLE        = "To capture",
	CAPTURE_Q_COUNT        = "Net: %d to capture",
	CAPTURE_Q_REASON_shiny = "Shiny!",
	CAPTURE_Q_REASON_new   = "Not captured yet",
	CAPTURE_Q_REASON_stars = "Could beat your %s specimen",
	CAPTURE_Q_WAIT         = "after combat",
	CAPTURE_Q_LEFT         = "%ds",
	CAPTURE_Q_CLICK        = "Click: capture %s",
	CAPTURE_Q_RIGHT        = "Right-click: the list (pick, aids, ignore all)",
	CAPTURE_Q_IGNORE       = "Ignore all",
	CAPTURE_Q_EMPTY        = "Nothing to capture right now.",
	CAPTURE_Q_LIST_HINT    = "Click a line to capture it. The chosen aid is used on the next try.",
	CAPTURE_Q_AID          = "Aid: %s",
	CAPTURE_STARS_LABEL    = "Quality: %s",
	CAPTURE_MSG_STARS      = "%s: %s.",
	CAPTURE_MSG_STARS_BEST = "%s: %s, your best specimen!",
	CAPTURE_MSG_STARS_KEPT = "%s: %s. Your %d-star specimen stays.",
	CAPTURE_STAGE_BEST     = "Best specimen yet!",
	CAPTURE_STAGE_KEPT     = "Yours keeps its %d stars",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_QUEUE_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end
local function Enabled()
	local on = ns.CompanionOn and ns.CompanionOn() or false
	return on and ns:DB().companionCapture ~= false
end
local function Tooltip() local t = G("GameTooltip"); if type(t) == "table" and t.SetOwner then return t end end

-- ---------------------------------------------------------------------------
-- Étoiles
-- ---------------------------------------------------------------------------
-- Les fiches d'avant les étoiles valent 1 étoile (une fois, à la lecture)
do
	local base = ns.CaptureData
	if base then
		function ns:CaptureData(...)
			local capture = base(self, ...)
			if not capture.starsV then
				for _, entry in pairs(capture.creatures) do
					if type(entry) == "table" then
						if entry.normal ~= false and entry.stars == nil then entry.stars = 1 end
						if entry.shiny and entry.shinyStars == nil then entry.shinyStars = 1 end
					end
				end
				capture.starsV = 1
			end
			return capture
		end
	end
end

-- 1 à 3, ou nil si cette version n'est pas capturée
function ns:CaptureStars(npcID, shiny)
	local entry = self:CaptureData().creatures[tonumber(npcID) or npcID]
	if type(entry) ~= "table" then return nil end
	local stars
	if shiny then
		if not entry.shiny then return nil end
		stars = entry.shinyStars
	else
		if entry.normal == false then return nil end
		stars = entry.stars
	end
	return math.max(1, math.min(ns.CAPTURE_STAR_MAX, math.floor(tonumber(stars) or 1)))
end

-- La qualité d'une capture : 1, 2 ou 3 étoiles (CAPTURE_STAR_ODDS)
function ns:CaptureRollStars()
	local odds, total = ns.CAPTURE_STAR_ODDS, 0
	for _, weight in ipairs(odds) do total = total + weight end
	local roll = math.random() * total
	for stars, weight in ipairs(odds) do
		roll = roll - weight
		if roll < 0 then return stars end
	end
	return #odds
end

-- Texte des étoiles (pleines dorées, vides grises), pour le chat et les fiches
local function StarIcon(full, size)
	local c = full and { 246, 199, 125 } or { 90, 90, 90 }
	return string.format("|T%s:%d:%d:0:0:16:16:0:16:0:16:%d:%d:%d|t", ns.CAPTURE_STAR_ICON, size, size, c[1], c[2], c[3])
end
function ns:CaptureStarsText(stars, size)
	stars = tonumber(stars)
	if not stars then return "" end
	local parts = {}
	for index = 1, ns.CAPTURE_STAR_MAX do parts[index] = StarIcon(index <= stars, size or 12) end
	return table.concat(parts)
end

-- La Ménagerie : chaque espèce porte ses étoiles (normale, brillante)
do
	local base = ns.MenagerieList
	if base then
		function ns:MenagerieList(...)
			local list, stats = base(self, ...)
			local creatures = self:CaptureData().creatures
			for _, item in ipairs(list or {}) do
				if item.captured and creatures[item.npc] then
					item.stars = self:CaptureStars(item.npc, false)
					item.shinyStars = self:CaptureStars(item.npc, true)
				end
			end
			return list, stats
		end
	end
end

-- ---------------------------------------------------------------------------
-- La file d'attente
-- ---------------------------------------------------------------------------
function ns:CaptureQueueState()
	local state = self:CaptureState()
	state.queue = state.queue or {}
	return state.queue
end

-- Pourquoi ce monstre vaut le coup : "shiny", "new", "stars", ou nil
function ns:CaptureQueueReason(candidate)
	local stars = self:CaptureStars(candidate.npcID, candidate.shiny and true or false)
	if not stars then return candidate.shiny and "shiny" or "new" end
	if stars < ns.CAPTURE_STAR_MAX then return "stars" end
	return nil
end

-- brillante > espèce nouvelle > plus rare > amélioration d'étoiles ; puis
-- celui dont le temps file le plus vite
local function Better(a, b)
	local sa, sb = a.shiny and 1 or 0, b.shiny and 1 or 0
	if sa ~= sb then return sa > sb end
	local na, nb = a.reason ~= "stars" and 1 or 0, b.reason ~= "stars" and 1 or 0
	if na ~= nb then return na > nb end
	local ra, rb = RANK_ORDER[a.class] or 1, RANK_ORDER[b.class] or 1
	if ra ~= rb then return ra > rb end
	local ca, cb = a.have or 0, b.have or 0
	if ca ~= cb then return ca < cb end
	local ea, eb = a.expires or math.huge, b.expires or math.huge
	if ea ~= eb then return ea < eb end
	return (a.serial or 0) < (b.serial or 0)
end

-- Remet la file à jour : raisons recalculées (une capture a pu changer la
-- donne), expirés et sans intérêt retirés, tri. Renvoie la file.
function ns:CaptureQueuePrune(now)
	local queue = self:CaptureQueueState()
	now = now or Clock()
	local kept = {}
	for _, candidate in ipairs(queue) do
		candidate.reason = self:CaptureQueueReason(candidate)
		candidate.have = self:CaptureStars(candidate.npcID, candidate.shiny and true or false)
		if candidate.reason and not (candidate.expires and now > candidate.expires) then kept[#kept + 1] = candidate end
	end
	table.sort(kept, Better)
	while #kept > ns.CAPTURE_QUEUE_MAX do table.remove(kept) end
	for index = #queue, 1, -1 do queue[index] = nil end
	for index, candidate in ipairs(kept) do queue[index] = candidate end
	return queue
end

-- La file triée : { guid, npcID, name, class, type, shiny, reason, expires }
-- (expires = nil : le combat n'est pas fini, le compte n'a pas commencé)
function ns:CaptureQueue()
	local list = {}
	for index, candidate in ipairs(self:CaptureQueuePrune()) do list[index] = candidate end
	return list
end

function ns:CaptureQueueBest()
	return self:CaptureQueuePrune()[1]
end

function ns:CaptureQueueHasShiny()
	for _, candidate in ipairs(self:CaptureQueueState()) do
		if candidate.shiny then return true end
	end
	return false
end

-- Le coup fatal (Capture.lua, BestiaryOnKill) : plus de fenêtre, la file.
-- `entry` : { zoneID, npcID } ; `shiny` : brillante abattue
function ns:CaptureOffer(guid, entry, shiny)
	if not Enabled() or type(entry) ~= "table" or not entry.npcID then return nil end
	local queue = self:CaptureQueueState()
	if guid then
		for _, candidate in ipairs(queue) do if candidate.guid == guid then return nil end end
	end
	-- l'aide choisie reste choisie… tant qu'il en reste
	local chosen = self:CaptureState().aid
	if chosen and self:CaptureAidCount(chosen) <= 0 then self:CaptureState().aid = nil end
	local npcID = tonumber(entry.npcID) or entry.npcID
	local book = self.BestiaryData and self:BestiaryData()
	local species = book and book[entry.zoneID] and book[entry.zoneID][entry.npcID] or {}
	local state = self:CaptureState()
	state.queueSerial = (state.queueSerial or 0) + 1
	local candidate = {
		guid = guid, npcID = npcID, zoneID = entry.zoneID,
		name = species.name or (type(shiny) == "table" and shiny.name) or tostring(npcID),
		class = species.class or "normal", level = species.level, type = species.type,
		family = species.family, shiny = shiny and true or nil, serial = state.queueSerial,
	}
	candidate.reason = self:CaptureQueueReason(candidate)
	if not candidate.reason then return nil end
	-- en plein combat, le compte attend la fin du combat
	if not InCombat() then candidate.expires = Clock() + ns.CAPTURE_QUEUE_TIME end
	queue[#queue + 1] = candidate
	self:CaptureQueuePrune()
	local still = false
	for _, c in ipairs(queue) do if c == candidate then still = true end end
	if not still then return nil end
	-- le compagnon le signale pour une nouveauté (pas pour chaque amélioration)
	if candidate.reason ~= "stars" then self:CompanionSay("CAPTURE_PROMPT", { args = { candidate.name } }) end
	self:CaptureQueueRefresh()
	return candidate
end

-- Retire un candidat (par son guid, ou la table elle-même)
function ns:CaptureQueueRemove(which)
	local queue = self:CaptureQueueState()
	for index = #queue, 1, -1 do
		local candidate = queue[index]
		if candidate == which or (which ~= nil and candidate.guid == which) then table.remove(queue, index) end
	end
	self:CaptureQueueRefresh()
end

function ns:CaptureQueueClear()
	local queue = self:CaptureQueueState()
	for index = #queue, 1, -1 do queue[index] = nil end
	self:CaptureHideQueueList()
	self:CaptureQueueRefresh()
end

-- Fin du combat : le compte à rebours démarre pour ceux qui attendaient
function ns:CaptureQueueStartTimers(now)
	now = now or Clock()
	local started = false
	for _, candidate in ipairs(self:CaptureQueueState()) do
		if not candidate.expires then
			candidate.expires = now + ns.CAPTURE_QUEUE_TIME
			started = true
		end
	end
	return started
end

-- ---------------------------------------------------------------------------
-- Un essai : le meilleur candidat (ou celui choisi), joué par Capture.lua
-- ---------------------------------------------------------------------------
-- ns:CaptureThrow(guid) : sans fenêtre ouverte, prend le candidat de la file
-- (celui de ce guid, sinon le meilleur). Renvoie true si le filet est lancé.
do
	local base = ns.CaptureThrow
	function ns:CaptureThrow(guid)
		local state = self:CaptureState()
		if state.rolling then return false end
		local picked
		if not state.pending or guid then
			local queue = self:CaptureQueuePrune()
			if guid then
				for _, candidate in ipairs(queue) do
					if candidate.guid == guid or candidate == guid then picked = candidate end
				end
			else
				picked = queue[1]
			end
			if not picked then return false end
			self:CaptureQueueRemove(picked)
			local pending = {}
			for key, value in pairs(picked) do pending[key] = value end
			pending.expires = Clock() + (ns.CAPTURE_WINDOW or 12)
			state.pending = pending
			-- l'aide choisie la dernière fois reste choisie s'il en reste
			if state.aid and self:CaptureAidCount(state.aid) <= 0 then state.aid = nil end
		end
		-- sans la scène animée : la petite fenêtre montre les secousses
		local staged = self.CaptureStageOn and self:CaptureStageOn() or false
		if not staged and self.CaptureShowPrompt then self:CaptureShowPrompt() end
		self:CaptureHideQueueList()
		local thrown = base(self)
		self:CaptureQueueRefresh()
		return thrown
	end
end

-- Le verdict : étoiles tirées, meilleur spécimen gardé
do
	local base = ns.CaptureResolve
	function ns:CaptureResolve(rolling)
		local target = rolling and rolling.target
		if not (target and rolling.success) then
			local result = base(self, rolling)
			self:CaptureQueueRefresh()
			return result
		end
		local shiny = target.shiny and true or false
		local before = self:CaptureStars(target.npcID, shiny)
		local old = self:CaptureData().creatures[target.npcID]
		local oldAt = old and (shiny and old.shinyAt or old.at)
		rolling.stars = rolling.stars or self:CaptureRollStars()
		rolling.starsBefore = before
		local result = base(self, rolling)
		local entry = self:CaptureData().creatures[target.npcID]
		if entry then
			local better = before == nil or rolling.stars > before
			local best = math.max(before or 0, rolling.stars)
			if shiny then entry.shinyStars = best else entry.stars = best end
			-- pas mieux : la date reste celle du spécimen gardé
			if not better and oldAt then
				if shiny then entry.shinyAt = oldAt else entry.at = oldAt end
			end
			rolling.starsBest, rolling.starsBetter = best, better
			-- les étoiles ont pu changer : les effets du compagnon (lot 2) se recalculent
			local capture = self:CaptureData()
			capture.serial = (tonumber(capture.serial) or 0) + 1
			self.captureAppCache = nil
			local text = self:CaptureStarsText(rolling.stars)
			if before == nil then
				self:Print(self:F("CAPTURE_MSG_STARS", target.name, text))
			elseif better then
				self:Print(self:F("CAPTURE_MSG_STARS_BEST", target.name, text))
			else
				self:Print(self:F("CAPTURE_MSG_STARS_KEPT", target.name, text, before))
			end
		end
		self:CaptureQueueRefresh()
		return result
	end
end

-- Horloge (Capture.lua) : la file aussi (fin du combat, temps écoulé)
do
	local base = ns.CaptureTick
	function ns:CaptureTick(now)
		base(self, now)
		local state = self.captureState
		local queue = state and state.queue
		if not (queue and #queue > 0) then return end
		local changed = false
		if not InCombat() and self:CaptureQueueStartTimers(now) then changed = true end
		local before = #queue
		self:CaptureQueuePrune(now)
		if #queue ~= before then changed = true end
		if changed then self:CaptureQueueRefresh() end
		if self.captureQueueList and self.captureQueueList:IsShown() then self:CaptureRefreshQueueList(now) end
	end
end

-- La scène : les étoiles du spécimen sous la rareté
do
	local base = ns.CaptureStageUpdate
	if base then
		function ns:CaptureStageUpdate(now)
			local phase = base(self, now)
			local frame = self.captureStage
			if not frame then return phase end
			if not frame.qcStars then
				frame.qcStars = Theme.Text(frame, Theme.F_BODY, Theme.PARCHMENT)
				frame.qcStars:SetPoint("TOP", frame.name, "BOTTOM", 0, -18)
				frame.qcStars:SetJustifyH("CENTER")
			end
			local rolling = frame.rolling
			if phase == "ok" and rolling and rolling.stars then
				frame.qcStars:SetText(self:CaptureStarsText(rolling.stars, 16))
				frame.qcStars:Show()
				local r = now - (rolling.resultAt or now)
				if rolling.starsBefore and r <= 1.2 then
					frame.footer:SetText(rolling.starsBetter and L.CAPTURE_STAGE_BEST
						or self:F("CAPTURE_STAGE_KEPT", rolling.starsBefore))
				end
			else
				frame.qcStars:SetText("")
				frame.qcStars:Hide()
			end
			return phase
		end
	end
end

-- ---------------------------------------------------------------------------
-- Le bouton filet, sur le cadre du compagnon
-- ---------------------------------------------------------------------------
local function ShowNetTooltip(button)
	local tooltip = Tooltip()
	if not tooltip then return end
	tooltip:SetOwner(button, "ANCHOR_TOP")
	local queue = ns:CaptureQueuePrune()
	Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_COUNT", #queue), Theme.GOLD)
	local best = queue[1]
	if best then
		local name = best.shiny and ns:F("CAPTURE_SHINY_TAG", best.name) or best.name
		Theme.TooltipLine(tooltip, ns:CaptureQueueLine(best), Theme.PARCHMENT)
		Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_CLICK", name), Theme.MUTED_LIGHT)
	end
	local aid = ns:CaptureState().aid
	if aid and ns:CaptureAidCount(aid) > 0 then
		Theme.TooltipLine(tooltip, ns:F("CAPTURE_Q_AID", ns:CaptureAidLabel(aid)), Theme.MUTED_LIGHT)
	end
	Theme.TooltipLine(tooltip, L.CAPTURE_Q_RIGHT, Theme.MUTED_LIGHT)
	tooltip:Show()
end

function ns:EnsureCaptureNet()
	local parent = self.companionFrame
	if not parent then return nil end
	if parent.captureNet then return parent.captureNet end
	local button = Theme.CreateIconButton(parent, NET_SIZE, NET_ICON)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
	button:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)
	if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	-- le halo doré d'une brillante, derrière l'icône
	button.glow = Theme.Solid(button, "BACKGROUND", Theme.GOLD_LIGHT, 0)
	button.glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
	button.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
	button.count = Theme.Text(button, Theme.F_SMALL, Theme.PARCHMENT)
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then ns:CaptureToggleQueueList() else ns:CaptureThrow() end
	end)
	button:SetScript("OnEnter", function(b) b.hover = true; ns:CaptureStyleNet(); ShowNetTooltip(b) end)
	button:SetScript("OnLeave", function(b)
		b.hover = nil
		ns:CaptureStyleNet()
		local tooltip = Tooltip()
		if tooltip and tooltip.Hide then tooltip:Hide() end
	end)
	-- scintillement : seulement quand une brillante attend
	button:SetScript("OnUpdate", function(b)
		if not b.shiny then return end
		b.glow:SetAlpha(0.20 + 0.35 * math.abs(math.sin(Clock() * 3)))
	end)
	button:Hide()
	parent.captureNet = button
	return button
end

-- Couleurs : ambre au repos, or plein (et halo) pour une brillante
function ns:CaptureStyleNet()
	local button = self.companionFrame and self.companionFrame.captureNet
	if not button then return end
	local lit = button.hover or button.shiny
	if button.icon.SetDesaturated then button.icon:SetDesaturated(false) end
	button.icon:SetAlpha(lit and 1 or 0.85)
	local c = button.shiny and Theme.GOLD_LIGHT or (button.hover and Theme.GOLD or Theme.EDGE)
	if button.border and button.border.SetColor then button.border:SetColor(c[1], c[2], c[3], 1) end
	if button.shiny then
		button.icon:SetVertexColor(1, 0.85, 0.4, 1)
	else
		button.icon:SetVertexColor(1, 1, 1, 1)
		button.glow:SetAlpha(0)
	end
end

-- Bouton et liste à jour (après chaque changement de la file)
function ns:CaptureQueueRefresh()
	local queue = self:CaptureQueueState()
	local frame = self.companionFrame
	local count = (Enabled() and #queue) or 0
	if frame then
		local button = frame.captureNet or (count > 0 and self:EnsureCaptureNet())
		if button then
			if count > 0 then
				button.count:SetText(tostring(count))
				button.shiny = self:CaptureQueueHasShiny()
				self:CaptureStyleNet()
				button:Show()
			else
				button.shiny = nil
				button:Hide()
			end
		end
	end
	if count == 0 then self:CaptureHideQueueList()
	elseif self.captureQueueList and self.captureQueueList:IsShown() then self:CaptureRefreshQueueList() end
	return count
end

-- ---------------------------------------------------------------------------
-- La liste (clic droit sur le filet)
-- ---------------------------------------------------------------------------
-- « Kodo · Pas encore capturée · 30 % · 24 s »
function ns:CaptureQueueLine(candidate, now)
	local reason = candidate.reason or "new"
	local parts = {}
	if reason == "stars" then
		parts[1] = self:F("CAPTURE_Q_REASON_stars", self:CaptureStarsText(candidate.have, 10))
	else
		parts[1] = L["CAPTURE_Q_REASON_" .. reason]
	end
	local state = self:CaptureState()
	local chance, sure = self:CaptureChance(candidate, state.aid)
	parts[#parts + 1] = sure and self:F("CAPTURE_SURE", L["CAPTURE_RANK_" .. tostring(candidate.class)])
		or self:F("CAPTURE_CHANCE", L["CAPTURE_RANK_" .. tostring(candidate.class)], math.floor(chance * 100 + 0.5 + 1e-9))
	if candidate.expires then
		parts[#parts + 1] = self:F("CAPTURE_Q_LEFT", math.max(0, math.ceil(candidate.expires - (now or Clock()))))
	else
		parts[#parts + 1] = L.CAPTURE_Q_WAIT
	end
	return table.concat(parts, " · ")
end

function ns:EnsureCaptureQueueList()
	if self.captureQueueList then return self.captureQueueList end
	if not (Theme and Theme.CreateToast) then return nil end
	local height = 34 + LIST_ROWS * LIST_ROW_H + 70
	local frame = Theme.CreateToast(UIParent, LIST_W, height, { strata = "HIGH" })
	if not frame then return nil end
	frame:EnableMouse(true)
	self:RestorePoint(frame, "captureListPoint", { point = "BOTTOM", x = 0, y = 260 })
	-- clic droit sur le fond : on referme
	frame:SetScript("OnMouseUp", function(_, mouse) if mouse == "RightButton" then ns:CaptureHideQueueList() end end)
	local pad = 12
	frame.title = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
	frame.title:SetText(L.CAPTURE_Q_TITLE)
	frame.rows = {}
	for index = 1, LIST_ROWS do
		local row = Theme.CreateListRow(frame, LIST_W - 2 * pad, LIST_ROW_H - 2,
			{ kind = "Button", detail = true, detailFont = Theme.F_SMALL, font = Theme.F_SMALL })
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -30 - (index - 1) * LIST_ROW_H)
		row:SetIndex(index)
		row.text:SetWidth(110)
		row.detail:SetWidth(LIST_W - 2 * pad - 130)
		row:SetScript("OnClick", function(r) if r.candidate then ns:CaptureThrow(r.candidate) end end)
		row:Hide()
		frame.rows[index] = row
	end
	frame.empty = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -34)
	frame.empty:SetText(L.CAPTURE_Q_EMPTY)
	-- les aides, comme dans l'ancienne fenêtre : choisies pour le prochain essai
	frame.aids = {}
	local aidY = pad + 30
	for index, aid in ipairs(ns.CAPTURE_AIDS or {}) do
		local button = Theme.CreateIconButton(frame, 24, aid.icon, function() ns:CaptureToggleAid(aid.id); ns:CaptureRefreshQueueList() end)
		button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad + (index - 1) * 30, aidY)
		button.count = Theme.Text(button, Theme.F_SMALL, Theme.PARCHMENT)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
		button.aid = aid.id
		button:SetScript("OnEnter", function(b)
			local tooltip = Tooltip()
			if not tooltip then return end
			tooltip:SetOwner(b, "ANCHOR_TOP")
			local count = ns:CaptureAidCount(aid.id)
			Theme.TooltipLine(tooltip, ns:CaptureAidLabel(aid.id), Theme.PARCHMENT)
			Theme.TooltipLine(tooltip, L["CAPTURE_AID_DESC_" .. aid.id], Theme.TEXT)
			Theme.TooltipLine(tooltip, count > 0 and ns:F("CAPTURE_AID_HINT", count) or L.CAPTURE_AID_NONE, Theme.MUTED_LIGHT)
			tooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			local tooltip = Tooltip()
			if tooltip and tooltip.Hide then tooltip:Hide() end
			ns:CaptureRefreshQueueList()
		end)
		frame.aids[index] = button
	end
	frame.ignore = Theme.CreateButton(frame, 100, Theme.DIALOG_BUTTON_HEIGHT or 28, L.CAPTURE_Q_IGNORE,
		function() ns:CaptureQueueClear() end)
	frame.ignore:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, aidY - 2)
	frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
	frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, pad - 2)
	frame.hint:SetWidth(LIST_W - 2 * pad)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L.CAPTURE_Q_LIST_HINT)
	frame:Hide()
	self.captureQueueList = frame
	return frame
end

function ns:CaptureRefreshQueueList(now)
	local frame = self.captureQueueList
	if not frame then return end
	local queue = self:CaptureQueueState()
	frame.title:SetText(self:F("CAPTURE_Q_COUNT", #queue))
	for index, row in ipairs(frame.rows) do
		local candidate = queue[index]
		row.candidate = candidate
		if candidate then
			local rarity = self.CaptureRarity and self:CaptureRarity(candidate)
			row.text:SetText(candidate.shiny and self:F("CAPTURE_SHINY_TAG", candidate.name) or candidate.name)
			local c = rarity and rarity.color or Theme.TEXT
			row.text:SetTextColor(c[1], c[2], c[3])
			row.detail:SetText(self:CaptureQueueLine(candidate, now))
			row:Show()
		else
			row:Hide()
		end
	end
	if #queue == 0 then frame.empty:Show() else frame.empty:Hide() end
	local state = self:CaptureState()
	for _, button in ipairs(frame.aids) do
		local count = self:CaptureAidCount(button.aid)
		button.count:SetText(count > 0 and tostring(count) or "")
		local chosen = state.aid == button.aid
		if button.icon.SetDesaturated then button.icon:SetDesaturated(not chosen) end
		button.icon:SetAlpha(chosen and 1 or (count > 0 and 0.6 or 0.25))
		local c = chosen and Theme.GOLD or Theme.EDGE
		if button.border and button.border.SetColor then button.border:SetColor(c[1], c[2], c[3], 1) end
	end
end

function ns:CaptureShowQueueList()
	local frame = self:EnsureCaptureQueueList()
	if not frame then return nil end
	self:CaptureQueuePrune()
	self:CaptureRefreshQueueList()
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	return frame
end

function ns:CaptureHideQueueList()
	if self.captureQueueList then self.captureQueueList:Hide() end
end

function ns:CaptureToggleQueueList()
	local frame = self.captureQueueList
	if frame and frame:IsShown() then self:CaptureHideQueueList(); return nil end
	return self:CaptureShowQueueList()
end

-- Le cadre du compagnon (re)créé : le filet s'y pose s'il y a de quoi
do
	local base = ns.EnsureCompanionFrame
	if base then
		function ns:EnsureCompanionFrame(...)
			local frame = base(self, ...)
			if frame and not frame.captureNet and self.captureState and self.captureState.queue
				and #self.captureState.queue > 0 then
				pcall(self.CaptureQueueRefresh, self)
			end
			return frame
		end
	end
end

if ns.Mark then ns.Mark("CaptureQueue") end
