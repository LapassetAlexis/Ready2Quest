-- CaptureExpress.lua -- Capture express (QuestCompanion 3.1.0)
--
-- Retour des joueurs : en plein pack, la capture coupait le rythme. Un
-- bandeau de 384 px, puis la carte de préparation, puis une scène de 3,5 s
-- au milieu de l'écran, et le choix à deux candidats : quatre fenêtres pour
-- un filet, et rien du tout en combat. La capture express garde les règles
-- (qualité au coup fatal, chance, aides, Réserve, méfiance) et retire les
-- fenêtres :
--   * un clic sur le filet (ou le raccourci) = un lancer, tranché tout de
--     suite ; on peut enchaîner les clics, y compris en combat (rien ne
--     s'ouvre) ;
--   * Maj+clic = tout le filet d'un coup ; Ctrl+clic = la carte de
--     préparation, comme avant (aides, Lancer, Passer) ; clic droit = la liste ;
--   * le verdict est une pastille d'une ligne au-dessus du filet (nom,
--     étoiles, liseré vert, rouge ou doré), qui glisse, brille et s'efface
--     seule. Elle ne prend jamais la souris. Le bandeau « Capture possible »
--     devient une pastille du même fil ;
--   * le chat et les bulles ne parlent plus que des prises qui comptent
--     (espèce nouvelle, brillante, meilleur spécimen) ;
--   * « Capture automatique » : le filet part seul au coup fatal. Une
--     brillante n'est jamais lancée seule sans aide : elle attend au filet ;
--   * « Aide conseillée automatique » : sur un 3 étoiles ou une brillante, la
--     meilleure aide en poche part avec le filet (le choix est gardé).
-- Réglage coupé (« Capture express ») : le déroulé d'avant, inchangé. La
-- visite guidée des premières captures garde aussi le déroulé d'avant.
-- Chargé en dernier : il enveloppe le filet, le bandeau, le raccourci, /qc filet.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_EXPRESS = {
	rows = 4,            -- pastilles à l'écran, la plus récente en bas
	w = 224, h = 20, gap = 2,
	life = 2.2,          -- s d'une pastille ordinaire
	lifeNotable = 3.6,   -- s d'une prise qui compte (nouvelle, brillante, record)
	slide = 0.15,        -- s de glissement à l'arrivée
	fade = 0.4,          -- s d'effacement
	flash = 0.35,        -- s d'éclat du liseré
	plate = 0.94,        -- opacité de la plaque d'encre (comme le filet)
	soundGap = 0.15,     -- s au moins entre deux fois le même son
	chimeGap = 3,        -- s au moins entre deux carillons « capture possible »
}
local X = ns.CAPTURE_EXPRESS

local FR = {
	OPT_DAILY_CAPTURE_EXPRESS      = "Capture express",
	OPT_DAILY_CAPTURE_EXPRESS_DESC = "Un clic sur le filet lance tout de suite, même en combat : pas de bandeau, pas de carte, pas de scène. Le verdict s'affiche en une ligne au-dessus du filet. Maj+clic : tout le filet. Ctrl+clic : la carte de préparation.",
	OPT_DAILY_CAPTURE_AUTO         = "Capture automatique",
	OPT_DAILY_CAPTURE_AUTO_DESC    = "Le filet part seul dès qu'un monstre abattu vaut le coup. Une brillante attend ton clic, sauf si une aide part avec elle. Demande la capture express.",
	OPT_DAILY_CAPTURE_AIDAUTO      = "Aide conseillée automatique",
	OPT_DAILY_CAPTURE_AIDAUTO_DESC = "En capture express, la meilleure aide en poche part avec le filet sur un 3 étoiles ou une brillante. Coupé : aucune aide n'est dépensée sans que tu la choisisses.",
	CAPTURE_X_NEW        = "nouvelle",
	CAPTURE_X_BEST       = "record",
	CAPTURE_X_FLED       = "échappée",
	CAPTURE_X_ALL        = "Filet : %d sur %d",
	CAPTURE_X_PCT        = "%d %%",
	CAPTURE_X_SURE       = "sûre",
	CAPTURE_X_TIP_CLICK  = "Clic : lancer sur %s",
	CAPTURE_X_TIP_SHIFT  = "Maj+clic : tout le filet (%d)",
	CAPTURE_X_TIP_CTRL   = "Ctrl+clic : préparer (aides, Lancer, Passer)",
	CAPTURE_X_MSG_AUTO_ON  = "Capture automatique activée : le filet part seul (une brillante attend ton clic si aucune aide ne part avec elle).",
	CAPTURE_X_MSG_AUTO_OFF = "Capture automatique coupée.",
	CAPTURE_X_MSG_ON     = "Capture express activée.",
	CAPTURE_X_MSG_OFF    = "Capture express coupée : carte de préparation et scène, comme avant.",
}
local EN = {
	OPT_DAILY_CAPTURE_EXPRESS      = "Express capture",
	OPT_DAILY_CAPTURE_EXPRESS_DESC = "Clicking the net throws right away, even in combat: no banner, no card, no scene. The result shows as one line above the net. Shift-click: the whole net. Ctrl-click: the preparation card.",
	OPT_DAILY_CAPTURE_AUTO         = "Automatic capture",
	OPT_DAILY_CAPTURE_AUTO_DESC    = "The net is thrown by itself as soon as a defeated monster is worth it. A shiny waits for your click, unless an aid goes with it. Needs express capture.",
	OPT_DAILY_CAPTURE_AIDAUTO      = "Recommended aid automatically",
	OPT_DAILY_CAPTURE_AIDAUTO_DESC = "In express capture, your best aid goes with the net on a 3-star or a shiny. Off: no aid is ever spent unless you pick it.",
	CAPTURE_X_NEW        = "new",
	CAPTURE_X_BEST       = "best",
	CAPTURE_X_FLED       = "escaped",
	CAPTURE_X_ALL        = "Net: %d of %d",
	CAPTURE_X_PCT        = "%d%%",
	CAPTURE_X_SURE       = "sure",
	CAPTURE_X_TIP_CLICK  = "Click: throw at %s",
	CAPTURE_X_TIP_SHIFT  = "Shift-click: the whole net (%d)",
	CAPTURE_X_TIP_CTRL   = "Ctrl-click: prepare (aids, Throw, Skip)",
	CAPTURE_X_MSG_AUTO_ON  = "Automatic capture on: the net is thrown by itself (a shiny waits for your click when no aid goes with it).",
	CAPTURE_X_MSG_AUTO_OFF = "Automatic capture off.",
	CAPTURE_X_MSG_ON     = "Express capture on.",
	CAPTURE_X_MSG_OFF    = "Express capture off: preparation card and scene, as before.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_EXPRESS_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ companionCaptureExpress = true, companionCaptureAuto = false, companionCaptureAidAuto = false })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local seen, at = {}, 1
	for index, row in ipairs(ns.DAILY_OPTION_ROWS) do
		seen[row.key] = true
		if row.key == "companionCapture" then at = index + 1 end
	end
	local function Row(key, label, desc)
		if seen[key] then return end
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = key, label = label, kind = "bool",
			describe = function() return L[desc] end })
		at = at + 1
	end
	Row("companionCaptureExpress", "OPT_DAILY_CAPTURE_EXPRESS", "OPT_DAILY_CAPTURE_EXPRESS_DESC")
	Row("companionCaptureAuto", "OPT_DAILY_CAPTURE_AUTO", "OPT_DAILY_CAPTURE_AUTO_DESC")
	Row("companionCaptureAidAuto", "OPT_DAILY_CAPTURE_AIDAUTO", "OPT_DAILY_CAPTURE_AIDAUTO_DESC")
end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Key(name)
	local fn = G(name)
	if type(fn) ~= "function" then return false end
	local ok, down = pcall(fn)
	return ok and down and true or false
end
local function Enabled()
	local on = ns.CompanionOn and ns.CompanionOn() or false
	return on and ns:DB().companionCapture ~= false
end
local function Pct(chance) return math.floor((chance or 0) * 100 + 0.5 + 1e-9) end
local function EaseOut(x)
	x = math.max(0, math.min(1, x))
	return 1 - (1 - x) * (1 - x)
end

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
-- La capture express est-elle en service ? (réglage ; jamais pendant une
-- visite guidée, qui montre la carte et la scène ; ns.captureExpressDormant :
-- le harnais de test l'endort hors de ses propres scénarios)
function ns:CaptureExpressOn()
	if ns.captureExpressDormant or not Enabled() then return false end
	if self:DB().companionCaptureExpress == false then return false end
	if self.TourActive and self:TourActive() then return false end
	return true
end

function ns:CaptureAutoOn()
	return self:CaptureExpressOn() and self:DB().companionCaptureAuto == true
end

-- L'aide qui part avec ce lancer : celle choisie (liste du filet) tant qu'il
-- en reste ; sinon, réglage « Aide conseillée automatique », la meilleure en
-- poche sur un 3 étoiles ou une brillante ; sinon aucune.
function ns:CaptureExpressAid(candidate)
	local chosen = self:CaptureState().aid
	if chosen and self:CaptureAidCount(chosen) > 0 then return chosen end
	if self:DB().companionCaptureAidAuto == true and self.CapturePrepAdvice then
		return self:CapturePrepAdvice(candidate)
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Le fil de pastilles : une ligne par événement, au-dessus du filet
-- ---------------------------------------------------------------------------
-- Aucune table n'est faite par pastille : les X.rows fiches tournent (la plus
-- ancienne est reprise pour la nouvelle), les cadres sont faits une fois.
local KIND_COLOR = {
	ok = Theme.GREEN, fail = Theme.RED, notable = Theme.GOLD_LIGHT, shiny = Theme.SHINY,
	offer = Theme.GOLD, all = Theme.GOLD,
}
ns.CAPTURE_EXPRESS_COLORS = KIND_COLOR

-- socle 3.2, thème forgé (maquette « thème forgé », .chip) : chaque pastille
-- est une petite carte en relief (Theme.ART.plate, 9 tranches : 4 pastilles
-- au plus), son liseré de couleur brille (Theme.ART.dot étiré, en lumière
-- ajoutée), les étoiles en or clair, un échec en rose pâle (pas le rouge du
-- liseré : lisible sur la carte). Textures faites une fois, à la construction.
do
	local K = ns.QC_FORGE or {}
	ns.CAPTURE_EXPRESS_FORGE = {
		card = K.card, margin = 5,       -- teinte de la carte, coin de la découpe (px)
		glowW = 20, glowOut = 6,         -- lueur du liseré : largeur, débord haut et bas
		glowAlpha = 0.9,
		right = Theme.GOLD_LIGHT,        -- étoiles, « 62 % », « nouvelle »
		failRight = K.danger,            -- « échappée »
		textLeft = 10,                   -- retrait du nom (après le liseré)
	}
end
local XF = ns.CAPTURE_EXPRESS_FORGE

local function BuildRow(feed, index)
	local row = CreateFrame("Frame", nil, feed)
	row:SetSize(X.w, X.h)
	if feed.forged then
		row.forged = true
		row.plate = Theme.Slice(row, "plate", { layer = "BACKGROUND", margin = XF.margin, color = XF.card, alpha = X.plate })
		row.glow = row:CreateTexture(nil, "BORDER", nil, 1)
		row.glow:SetTexture(Theme.ART.dot.file)
		row.glow:SetPoint("TOPLEFT", row, "TOPLEFT", 1.5 - XF.glowW / 2, XF.glowOut)
		row.glow:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", 1.5 + XF.glowW / 2, -XF.glowOut)
		if row.glow.SetBlendMode then pcall(row.glow.SetBlendMode, row.glow, "ADD") end
		row.glow:SetAlpha(XF.glowAlpha)
	else
		row.plate = Theme.Solid(row, "BACKGROUND", Theme.INK, X.plate)
		row.plate:SetAllPoints()
	end
	-- l'éclat : toute la ligne à la couleur du verdict, qui retombe aussitôt
	row.flash = Theme.Solid(row, "BORDER", Theme.WHITE, 0)
	row.flash:SetAllPoints()
	if row.flash.SetBlendMode then pcall(row.flash.SetBlendMode, row.flash, "ADD") end
	row.accent = Theme.Solid(row, "ARTWORK", Theme.GOLD, 1)
	row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.accent:SetWidth(3)
	row.right = Theme.Text(row, Theme.F_SMALL, Theme.PARCHMENT)
	row.right:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.right:SetJustifyH("RIGHT")
	row.text = Theme.Text(row, Theme.F_SMALL, Theme.PARCHMENT)
	row.text:SetPoint("LEFT", row, "LEFT", row.forged and XF.textLeft or 9, 0)
	row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
	row.text:SetJustifyH("LEFT")
	if row.text.SetWordWrap then row.text:SetWordWrap(false) end
	if row.EnableMouse then row:EnableMouse(false) end
	row.index = index
	row:Hide()
	return row
end

function ns:EnsureCaptureExpressFeed()
	local feed = self.captureExpressFeed
	if feed then return feed end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not (ok and frame) then return nil end
	feed = frame
	feed:SetSize(X.w, X.rows * (X.h + X.gap))
	feed.forged = ns.QCForged and ns.QCForged() or nil
	if feed.SetFrameStrata then pcall(feed.SetFrameStrata, feed, "MEDIUM") end
	-- jamais la souris : le fil se lit, il ne se clique pas
	if feed.EnableMouse then feed:EnableMouse(false) end
	feed.rows, feed.items = {}, {}
	for index = 1, X.rows do
		feed.rows[index] = BuildRow(feed, index)
		feed.items[index] = {}
	end
	feed:Hide()
	self.captureExpressFeed = feed
	return feed
end

-- Au-dessus du filet (à gauche du compagnon : aligné à droite, pour ne pas
-- sortir de l'écran) ; sans filet possible, au-dessus de sa place seule
function ns:CaptureExpressPlace()
	local feed = self.captureExpressFeed
	if not feed then return nil end
	local net = self.captureNetButton or (self.EnsureCaptureNet and self:EnsureCaptureNet())
	feed:ClearAllPoints()
	if net then
		local side = net.side == "left" and "RIGHT" or "LEFT"
		feed:SetPoint("BOTTOM" .. side, net, "TOP" .. side, 0, 10)
		feed.side = side
	else
		local spot = ns.CAPTURE_NET_ALONE or { point = "CENTER", x = 0, y = -170 }
		feed:SetPoint("BOTTOM", UIParent, spot.point, spot.x, spot.y + 34)
		feed.side = "LEFT"
	end
	return feed.side
end

-- Une pastille de plus : `kind` (ok, fail, notable, shiny, offer, all), le
-- texte de gauche, celui de droite. La plus ancienne fiche est reprise.
function ns:CaptureExpressPush(kind, text, right, life)
	local feed = self:EnsureCaptureExpressFeed()
	if not feed then return nil end
	local items = feed.items
	local item = items[X.rows]
	for index = X.rows, 2, -1 do items[index] = items[index - 1] end
	items[1] = item
	item.kind, item.text, item.right = kind, text or "", right or ""
	item.born = Clock()
	item.life = life or ((kind == "notable" or kind == "shiny") and X.lifeNotable or X.life)
	feed.dirty = true
	if not feed:IsShown() then
		self:CaptureExpressPlace()
		feed:Show()
	end
	-- (la tâche d'horloge n'est posée qu'une fois tant que le fil vit)
	if not feed.ticking then
		feed.ticking = true
		ns.Every("captureExpress", 0, ns.CaptureExpressFrame)
	end
	return item
end

-- Une image du fil. Rend le nombre de pastilles encore à l'écran.
function ns:CaptureExpressUpdate(now)
	local feed = self.captureExpressFeed
	if not feed then return 0 end
	now = now or Clock()
	local dirty, live = feed.dirty, 0
	feed.dirty = nil
	for index = 1, X.rows do
		local item, row = feed.items[index], feed.rows[index]
		local age = item.born and (now - item.born) or nil
		if not age or age >= item.life or age < 0 then
			item.born = nil
			if row.shownKind then row.shownKind = nil; row:Hide() end
		else
			live = live + 1
			if dirty or row.shownItem ~= item or row.shownKind ~= item.kind then
				local c = KIND_COLOR[item.kind] or Theme.GOLD
				row.accent:SetVertexColor(c[1], c[2], c[3], 1)
				row.flash:SetVertexColor(c[1], c[2], c[3], 1)
				if row.glow then row.glow:SetVertexColor(c[1], c[2], c[3], 1) end
				local ink = item.kind == "fail" and Theme.MUTED_LIGHT or (item.kind == "shiny" and Theme.SHINY or Theme.PARCHMENT)
				row.text:SetTextColor(ink[1], ink[2], ink[3])
				local rc = item.kind == "fail" and Theme.RED or Theme.PARCHMENT
				if row.forged then rc = item.kind == "fail" and XF.failRight or XF.right end
				row.right:SetTextColor(rc[1], rc[2], rc[3])
				row.text:SetText(item.text)
				row.right:SetText(item.right)
				row.shownItem, row.shownKind, row.slid = item, item.kind, nil
				row:Show()
			end
			-- glissement à l'arrivée (la ligne du bas seulement), puis en place
			local slide = age < X.slide and (1 - EaseOut(age / X.slide)) or 0
			if slide > 0 or not row.slid then
				row:ClearAllPoints()
				row:SetPoint("BOTTOMLEFT", feed, "BOTTOMLEFT", (index == 1 and slide or 0) * 14, (index - 1) * (X.h + X.gap))
				row.slid = slide == 0 or nil
			end
			local alpha = 1
			if age < X.slide and index == 1 then alpha = age / X.slide end
			local left = item.life - age
			if left < X.fade then alpha = math.min(alpha, left / X.fade) end
			row:SetAlpha(math.max(0, math.min(1, alpha)))
			row.flash:SetAlpha(age < X.flash and 0.5 * (1 - age / X.flash) or 0)
		end
	end
	if live == 0 and feed:IsShown() then feed:Hide() end
	return live
end

-- La tâche d'horloge (une seule fonction, jamais refaite) : se retire d'elle-même
function ns.CaptureExpressFrame()
	if ns:CaptureExpressUpdate(Clock()) == 0 then
		local feed = ns.captureExpressFeed
		if feed then feed.ticking = nil end
		return false
	end
end

-- ---------------------------------------------------------------------------
-- Un lancer express
-- ---------------------------------------------------------------------------
local function Quiet() end
local function QuietSay() return false, "express" end

-- Cette prise compte-t-elle ? (brillante, espèce nouvelle, meilleur spécimen)
local function Notable(self, target)
	if target.shiny then return true end
	local have = self:CaptureStars(target.npcID, false)
	return have == nil or (tonumber(target.stars) or 1) > have
end
ns.CaptureExpressNotable = Notable

-- La pastille d'un verdict
local function PushResult(self, rolling, before)
	local target = rolling.target
	local name = target.name or tostring(target.npcID)
	if not rolling.success then
		return self:CaptureExpressPush("fail", name, L.CAPTURE_X_FLED)
	end
	local stars = self:CaptureStarsText(rolling.stars or target.stars or 1, 10)
	if target.shiny then return self:CaptureExpressPush("shiny", self:F("CAPTURE_SHINY_TAG", name), stars) end
	if before == nil then return self:CaptureExpressPush("notable", name, L.CAPTURE_X_NEW .. " " .. stars) end
	if rolling.starsBetter then return self:CaptureExpressPush("notable", name, L.CAPTURE_X_BEST .. " " .. stars) end
	return self:CaptureExpressPush("ok", name, stars)
end

-- Lance le filet sur `which` (un candidat de la file, son guid, ou le
-- meilleur) et tranche tout de suite. Rend le lancer, ou false et la raison
-- ("off", "busy", "empty", "blocked").
function ns:CaptureExpressThrow(which, opts)
	if not self:CaptureExpressOn() then return false, "off" end
	local state = self:CaptureState()
	-- le verdict d'une scène encore à l'écran : on le referme et on enchaîne
	if state.rolling and state.rolling.result then
		state.rolling.closeAt = Clock()
		self:CaptureTick(Clock())
	end
	if state.rolling then return false, "busy" end
	local queue = self:CaptureQueuePrune()
	local picked
	if which ~= nil then
		for index = 1, #queue do
			local candidate = queue[index]
			if candidate == which or candidate.guid == which then picked = candidate; break end
		end
	else
		picked = queue[1]
	end
	if not picked then return false, "empty" end
	if self.CaptureRefuseBlocked and self:CaptureRefuseBlocked(picked) then return false, "blocked" end
	if self.TourSignal then pcall(self.TourSignal, self, "throw") end
	local aid = self:CaptureExpressAid(picked)
	self:CaptureQueueRemove(picked)
	picked.expires = nil
	local before = self:CaptureStars(picked.npcID, picked.shiny and true or false)
	local notable = Notable(self, picked)
	if not (opts and opts.silent) then self:CapturePlaySound("throw") end
	local rolling = self:CaptureRoll(picked, aid)
	rolling.express = true
	-- prise ordinaire : ni chat, ni bulle, ni bandeau « Capturé ! » (AzerothStyle.lua)
	rolling.quiet = not notable or nil
	rolling.result = rolling.success and "ok" or "fail"
	-- l'aide ne sert qu'à ce lancer (comme la carte et la volée)
	state.aid = nil
	-- une prise ordinaire ne remplit ni le chat ni les bulles : la pastille suffit
	local print, say = self.Print, self.CompanionSay
	if not notable then self.Print, self.CompanionSay = Quiet, QuietSay end
	self.captureExpressResolving = true
	local done, err = pcall(self.CaptureResolve, self, rolling)
	self.captureExpressResolving = nil
	self.Print, self.CompanionSay = print, say
	if not done and self.RecordError then self:RecordError("capture:express", err) end
	if not (opts and opts.quietFeed) then PushResult(self, rolling, before) end
	if self.TourSignal then pcall(self.TourSignal, self, "result", rolling.success and true or false) end
	self:CaptureQueueRefresh()
	return rolling
end

-- Tout le filet d'un coup. Rend le nombre de prises et le nombre d'essais.
function ns:CaptureExpressAll()
	if not self:CaptureExpressOn() then return 0, 0 end
	local got, tried = 0, 0
	-- (la file se vide à mesure ; un candidat bloqué reste : on s'arrête sur lui)
	for _ = 1, (ns.CAPTURE_QUEUE_MAX or 12) do
		local rolling = self:CaptureExpressThrow(nil, tried > 0 and { silent = true } or nil)
		if not rolling then break end
		tried = tried + 1
		if rolling.success then got = got + 1 end
	end
	if tried >= 2 then self:CaptureExpressPush("all", self:F("CAPTURE_X_ALL", got, tried), "") end
	return got, tried
end

-- Les sons d'une rafale ne se marchent pas dessus : le même son, au plus
-- toutes les X.soundGap secondes
do
	local base = ns.CapturePlaySound
	local last = {}
	if base then
		function ns:CapturePlaySound(key, ...)
			if self:CaptureExpressOn() then
				local now = Clock()
				local at = last[key]
				if at and now - at < X.soundGap and now >= at then return false end
				last[key] = now
			end
			return base(self, key, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- « Capture possible » : une pastille, plus de bandeau
-- ---------------------------------------------------------------------------
function ns:CaptureExpressAnnounce()
	if self.captureExpressOffering then return nil end
	if self:DB().companionCaptureToast == false or self:CaptureMuted() then return nil end
	local best = self:CaptureQueuePrune()[1]
	if not best then return nil end
	local feed = self:EnsureCaptureExpressFeed()
	if not feed or feed.announced == best.serial then return nil end
	feed.announced = best.serial
	local chance, sure = self:CaptureChance(best, self:CaptureExpressAid(best))
	local right = (sure and L.CAPTURE_X_SURE or self:F("CAPTURE_X_PCT", Pct(chance)))
		.. " " .. self:CaptureStarsText(best.stars or 1, 10)
	local name = best.shiny and self:F("CAPTURE_SHINY_TAG", best.name) or best.name
	local item = self:CaptureExpressPush(best.shiny and "shiny" or "offer", name, right)
	-- le carillon : une brillante toujours, sinon au plus toutes les X.chimeGap s
	local now = Clock()
	if best.shiny or not feed.chimedAt or now - feed.chimedAt >= X.chimeGap or now < feed.chimedAt then
		feed.chimedAt = now
		self:CapturePlaySound("ready")
	end
	return item
end

do
	local show = ns.CaptureToastShow
	if show then
		function ns:CaptureToastShow(...)
			if not self:CaptureExpressOn() then return show(self, ...) end
			if self.captureToast and self.captureToast:IsShown() then self:CaptureToastHide() end
			self:CaptureExpressAnnounce()
			return nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- Capture automatique : le filet part au coup fatal
-- ---------------------------------------------------------------------------
do
	local offer = ns.CaptureOffer
	if offer then
		function ns:CaptureOffer(...)
			if not self:CaptureAutoOn() then return offer(self, ...) end
			-- (pas de pastille « capture possible » pour un filet qui part aussitôt)
			self.captureExpressOffering = true
			local ok, candidate = pcall(offer, self, ...)
			self.captureExpressOffering = nil
			if not ok then error(candidate, 0) end
			if not candidate then return nil end
			-- une brillante ne part jamais seule sans aide : elle attend au filet
			if candidate.shiny and not self:CaptureExpressAid(candidate) then
				self:CaptureExpressAnnounce()
				return candidate
			end
			if not self:CaptureExpressThrow(candidate) then self:CaptureExpressAnnounce() end
			return candidate
		end
	end
end

-- ---------------------------------------------------------------------------
-- Les entrées : le filet, le raccourci, la liste, /qc filet
-- ---------------------------------------------------------------------------
do
	local click = ns.CaptureNetClick
	if click then
		function ns:CaptureNetClick(mouse, ...)
			if mouse == "RightButton" or not self:CaptureExpressOn() then return click(self, mouse, ...) end
			-- la carte ouverte : le clic la referme (comme avant)
			if self.CapturePrepShown and self:CapturePrepShown() then return click(self, mouse, ...) end
			if Key("IsControlKeyDown") and self.CapturePrepOpen then return self:CapturePrepOpen() end
			if Key("IsShiftKeyDown") then return self:CaptureExpressAll() end
			return self:CaptureExpressThrow()
		end
	end
end

-- L'infobulle du filet en capture express ; rend true si elle a écrit ses lignes
function ns:CaptureExpressTipLines(tooltip, queue, name)
	if not self:CaptureExpressOn() then return false end
	Theme.TooltipLine(tooltip, self:F("CAPTURE_X_TIP_CLICK", name), Theme.MUTED_LIGHT)
	if #queue >= 2 then Theme.TooltipLine(tooltip, self:F("CAPTURE_X_TIP_SHIFT", #queue), Theme.MUTED_LIGHT) end
	Theme.TooltipLine(tooltip, L.CAPTURE_X_TIP_CTRL, Theme.MUTED_LIGHT)
	return true
end

-- Une ligne de la liste (clic droit sur le filet) : en express, le filet part
-- et la liste reste ouverte pour la suivante
function ns:CaptureListPick(candidate)
	if not candidate then return false end
	if self:CaptureExpressOn() then
		local rolling = self:CaptureExpressThrow(candidate)
		if self.captureQueueList and self.captureQueueList:IsShown() then self:CaptureRefreshQueueList() end
		return rolling and true or false
	end
	self:CaptureHideQueueList()
	return self:CaptureThrow(candidate) and true or false
end

-- Le raccourci : en express il lance aussi en combat
do
	local bind = ns.BindingThrowNet
	if bind then
		function ns:BindingThrowNet(...)
			if not self:CaptureExpressOn() or (self.CapturePrepShown and self:CapturePrepShown()) then return bind(self, ...) end
			local rolling, why = self:CaptureExpressThrow()
			if not rolling and why == "empty" then self:Print(L.CAPTURE_Q_NOTHING) end
			return rolling and true or false
		end
	end
end

-- /qc filet (le meilleur), /qc filet tout, /qc filet auto, /qc filet express
if ns.EXTRA_COMMANDS and ns.EXTRA_COMMANDS["filet"] then
	local base = ns.EXTRA_COMMANDS["filet"]
	ns.EXTRA_COMMANDS["filet"] = function(self, rest, ...)
		local sub = tostring(rest or ""):match("^%s*(%S*)")
		sub = (sub or ""):lower()
		if sub == "auto" then
			local on = self:DB().companionCaptureAuto ~= true
			self:DB().companionCaptureAuto = on
			self:Print(on and L.CAPTURE_X_MSG_AUTO_ON or L.CAPTURE_X_MSG_AUTO_OFF)
			if self.RefreshOptions then pcall(self.RefreshOptions, self) end
			return
		elseif sub == "express" then
			local on = self:DB().companionCaptureExpress == false
			self:DB().companionCaptureExpress = on
			self:Print(on and L.CAPTURE_X_MSG_ON or L.CAPTURE_X_MSG_OFF)
			if self.RefreshOptions then pcall(self.RefreshOptions, self) end
			return
		end
		if not self:CaptureExpressOn() then return base(self, rest, ...) end
		if sub == "tout" or sub == "all" then
			local _, tried = self:CaptureExpressAll()
			if tried == 0 then self:Print(L.CAPTURE_Q_NOTHING) end
			return
		elseif sub == "" then
			local rolling, why = self:CaptureExpressThrow()
			if not rolling and why == "empty" then self:Print(L.CAPTURE_Q_NOTHING) end
			return
		end
		return base(self, rest, ...)
	end
	ns.EXTRA_COMMANDS["net"] = ns.EXTRA_COMMANDS["filet"]
end

if ns.Mark then ns.Mark("CaptureExpress") end
