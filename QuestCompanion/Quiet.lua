-- Quiet.lua -- moins de bruit, mieux dit (QuestCompanion 3.7.0)
--
-- Le catalogue des hauts faits double : il faut que le bruit baisse.
--   * Trois tailles de fête (la taille vient du moteur, ns:FeatSize) : un
--     petit haut fait (5 points) n'a plus de bandeau, mais une PASTILLE
--     muette de 2 secondes, faite des briques de la pastille de la capture
--     express, qui ne prend pas le créneau des bandeaux (Banners.lua) et
--     n'en retarde aucun ; le bandeau moyen dit sa récompense (« 5 paillettes
--     · lasso ») ; le grand dit le titre et ses paillettes, et signe.
--   * La SIGNATURE « QUEST COMPANION », précédée de la patte du logo (une
--     texture de l'addon), en haut à droite du grand bandeau de haut fait, du
--     « Capturé ! » d'une prise rare et du « Brillant capturé ! ».
--   * La COTE d'une prise rare : ns:SpecimenOdds(spec) rend N (« 1 chance sur
--     N ») pour les tirages rares que porte le spécimen, produit des chances
--     DE BASE lues dans les tables du jeu (brillante, 3 étoiles d'un monstre
--     ordinaire, taille Minuscule ou Géant, caractère rare) ; affichée après
--     la prise seulement, à partir de 1 sur QUIET_ODDS_MIN, jamais la chance
--     réelle (série de chasse, sceau, Rayonnant l'améliorent).
--   * Le MODE DISCRET (réglage au compte `quiet`, éteint) : ns:Quiet(). Une
--     garde à l'endroit où chaque source décide de parler (astuces, blagues,
--     histoire des lieux, indices, objectifs, annonces automatiques) : rien
--     n'attend en file pour sortir en rafale quand on l'éteint. Les hauts
--     faits passent en pastille muette, quelle que soit leur taille.
--   * L'INDICE d'un secret : au repos, une fois par semaine au plus (compte),
--     dans le créneau des astuces (Discovery.lua), hors mode discret.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.QUIET_ODDS_MIN = 100            -- cote affichée à partir de 1 chance sur 100
ns.QUIET_GUILD_GAP = 600           -- s : mode discret, un bandeau de guilde au plus
ns.QUIET_HINT_GAP = 7 * 86400      -- s : un indice de secret par semaine au plus
ns.QUIET_HINT_ID = "featHint"      -- l'entrée de l'indice dans le créneau des astuces
-- la pastille d'un haut fait : la pastille de la capture express (mêmes
-- briques, liseré ambre), 2 s, au-dessus du couloir des bandeaux
ns.FEAT_PILL = { life = 2, y = -120, w = 224, h = 20, textLeft = 10, right = 6 }
-- la signature : patte (texture du logo), écart, recul du bord droit
ns.QC_SIGNATURE = { icon = 11, gap = 5 }

local FR = {
	QC_SIGNATURE        = "QUEST COMPANION",
	FEAT_PILL_ONE       = "Haut fait : %s",
	FEAT_PILL_MANY      = "%d hauts faits",
	FEAT_PILL_POINTS_ONE  = "%d point",
	FEAT_PILL_POINTS_MANY = "%d points",
	FEAT_GLITTER_N      = "%d paillettes",
	FEAT_REWARD_SEP     = " · ",
	SPEC_ODDS_LINE      = "Rareté de base : 1 chance sur %s",
	SOUVENIR_BUTTON     = "Carte souvenir",
}
local EN = {
	QC_SIGNATURE        = "QUEST COMPANION",
	FEAT_PILL_ONE       = "Achievement: %s",
	FEAT_PILL_MANY      = "%d achievements",
	FEAT_PILL_POINTS_ONE  = "%d point",
	FEAT_PILL_POINTS_MANY = "%d points",
	FEAT_GLITTER_N      = "%d glitter",
	FEAT_REWARD_SEP     = " · ",
	SPEC_ODDS_LINE      = "Base rarity: 1 in %s",
	SOUVENIR_BUTTON     = "Souvenir card",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.QUIET_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ quiet = false })

local function G(name) return rawget(_G, name) end
local function Call(name, ...)
	local fn = G(name)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function Now() return (ns.Now and ns.Now()) or 0 end
local function Wall() return tonumber(Call("time")) or 0 end

-- ---------------------------------------------------------------------------
-- Mode discret
-- ---------------------------------------------------------------------------
function ns:Quiet() return self:DB().quiet == true end

-- ---------------------------------------------------------------------------
-- Cotes des prises rares
-- ---------------------------------------------------------------------------
-- Part d'un poids dans sa table (0 si absent)
local function Share(list, id, idOf, weightOf)
	local total, mine = 0, 0
	for _, item in ipairs(list or {}) do
		local w = tonumber(weightOf(item)) or 0
		total = total + w
		if idOf(item) == id then mine = w end
	end
	if total <= 0 then return 0 end
	return mine / total
end

-- Les chances de base des tirages rares que porte le spécimen : { [tirage] = p }
function ns:SpecimenOddsParts(spec)
	if type(spec) ~= "table" then return {} end
	local parts = {}
	if spec.shiny then parts.shiny = tonumber(ns.SHINY_CHANCE) or 0 end
	-- 3 étoiles : la meilleure qualité d'un monstre ordinaire (le tirage de base)
	local normal = ns.CAPTURE_QUALITY_ODDS and ns.CAPTURE_QUALITY_ODDS.normal
	local stars = tonumber(spec.stars)
	if normal and stars and stars >= #normal and #normal > 0 then parts.stars = (tonumber(normal[#normal]) or 0) / 100 end
	local size
	for _, entry in ipairs(ns.SPECIMEN_SIZES or {}) do
		if entry.id == spec.size and entry.rare then size = entry end
	end
	if size then
		parts.size = Share(ns.SPECIMEN_SIZES, size.id, function(e) return e.id end, function(e) return e.weight end)
	end
	if spec.trait and ns.SPECIMEN_TRAIT_RARE and ns.SPECIMEN_TRAIT_RARE[spec.trait] then
		parts.trait = Share(ns.SPECIMEN_TRAIT_WEIGHTS, spec.trait, function(e) return e[1] end, function(e) return e[2] end)
	end
	return parts
end

-- N (« 1 chance sur N ») pour la combinaison de tirages rares du spécimen
-- (table ou identifiant), ou nil s'il n'en porte aucun
function ns:SpecimenOdds(spec)
	if type(spec) ~= "table" and spec ~= nil and self.SpecimenGet then spec = self:SpecimenGet(spec) end
	if type(spec) ~= "table" then return nil end
	local p, any = 1, false
	for _, value in pairs(self:SpecimenOddsParts(spec)) do
		if value > 0 then p, any = p * value, true end
	end
	if not any or p <= 0 then return nil end
	return math.floor(1 / p + 0.5)
end

-- La cote à montrer (N), seulement à partir de 1 sur QUIET_ODDS_MIN
function ns:SpecimenOddsShown(spec)
	local n = self:SpecimenOdds(spec)
	if n and n >= ns.QUIET_ODDS_MIN then return n end
	return nil
end

-- « 107 143 » (français), « 107,143 » (anglais), « 107.143 » (espagnol)
local SEPARATOR = { fr = " ", en = ",", es = "." }
function ns.OddsNumber(n, lang)
	lang = lang or ns.STRINGS_LANG or (ns.STRINGS_FRENCH and "fr") or "en"
	local sep = SEPARATOR[lang] or ","
	local digits = tostring(math.floor(tonumber(n) or 0))
	local out = digits:reverse():gsub("(%d%d%d)", "%1" .. sep:reverse()):reverse()
	if out:sub(1, #sep) == sep then out = out:sub(#sep + 1) end
	return out
end

-- « Rareté de base : 1 chance sur 107 143 », ou nil (sous le seuil)
function ns:SpecimenOddsText(spec)
	local n = self:SpecimenOddsShown(spec)
	if not n then return nil end
	return self:F("SPEC_ODDS_LINE", ns.OddsNumber(n))
end

-- ---------------------------------------------------------------------------
-- La ligne de récompense d'un haut fait : « Nouveau titre : X · 40
-- paillettes », « 5 paillettes · Lasso ×1 » (les paillettes ne s'écrivent
-- jamais dans une ligne de chat par haut fait)
-- ---------------------------------------------------------------------------
function ns:FeatRewardLine(def)
	if type(def) ~= "table" and self.FeatDef then def = self:FeatDef(def) end
	if type(def) ~= "table" then return nil end
	local parts, reward = {}, type(def.reward) == "table" and def.reward or nil
	if reward and reward.title and self.FeatTitleText then
		local title = self:FeatTitleText(reward.title)
		if title then parts[#parts + 1] = self:F("FEAT_TOAST_NEW_TITLE", title) end
	end
	local glitter = self.FeatGlitterOf and tonumber(self:FeatGlitterOf(def)) or 0
	if glitter > 0 then parts[#parts + 1] = self:F("FEAT_GLITTER_N", glitter) end
	if reward and self.FeatRewardText then
		local copy = {}
		for k, v in pairs(reward) do copy[k] = v end
		copy.title = nil
		local ok, text = pcall(self.FeatRewardText, self, { id = def.id, reward = copy })
		if ok and type(text) == "string" and text ~= "" then parts[#parts + 1] = text end
	end
	if #parts == 0 then return nil end
	return table.concat(parts, L.FEAT_REWARD_SEP)
end

-- ---------------------------------------------------------------------------
-- Pastille d'un haut fait : muette, 2 s, hors du couloir des bandeaux
-- ---------------------------------------------------------------------------
ns.featPills = ns.featPills or {}

-- Cette entrée du carnet (Journal.lua) part-elle en pastille ? Un petit haut
-- fait (hors rattrapage, qui garde son bandeau groupé muet) ; en mode
-- discret, tous les hauts faits.
function ns:FeatPillWanted(entry)
	if type(entry) ~= "table" or entry.kind ~= "feat" then return false end
	if self:Quiet() then return true end
	return entry.size == "small" and not entry.retro
end

-- Le texte de gauche et celui de droite d'une pastille
function ns:FeatPillText(entry)
	local left
	if tonumber(entry.count) then left = self:F("FEAT_PILL_MANY", entry.count)
	else left = self:F("FEAT_PILL_ONE", tostring(entry.name or "")) end
	local points = tonumber(entry.points) or 0
	local right = self:F(points == 1 and "FEAT_PILL_POINTS_ONE" or "FEAT_PILL_POINTS_MANY", points)
	return left, right
end

local function BuildPill()
	local P = ns.FEAT_PILL
	local ok, row = pcall(CreateFrame, "Frame", nil, UIParent)
	if not (ok and row) then return nil end
	row:SetSize(P.w, P.h)
	if row.SetFrameStrata then pcall(row.SetFrameStrata, row, "MEDIUM") end
	if row.EnableMouse then row:EnableMouse(false) end
	local X = ns.CAPTURE_EXPRESS or {}
	local XF = ns.CAPTURE_EXPRESS_FORGE or {}
	-- les briques de la pastille de la capture express (CaptureExpress.lua)
	if ns.QCForged and ns.QCForged() and Theme.Slice and Theme.ART and Theme.ART.dot then
		row.forged = true
		row.plate = Theme.Slice(row, "plate", { layer = "BACKGROUND", margin = XF.margin or 5, color = XF.card, alpha = X.plate or 0.94 })
		row.glow = row:CreateTexture(nil, "BORDER", nil, 1)
		row.glow:SetTexture(Theme.ART.dot.file)
		local gw, go = XF.glowW or 20, XF.glowOut or 6
		row.glow:SetPoint("TOPLEFT", row, "TOPLEFT", 1.5 - gw / 2, go)
		row.glow:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", 1.5 + gw / 2, -go)
		if row.glow.SetBlendMode then pcall(row.glow.SetBlendMode, row.glow, "ADD") end
		row.glow:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		row.glow:SetAlpha(XF.glowAlpha or 0.9)
	else
		row.plate = Theme.Solid(row, "BACKGROUND", Theme.INK, X.plate or 0.94)
		row.plate:SetAllPoints()
	end
	row.accent = Theme.Solid(row, "ARTWORK", Theme.GOLD, 1)
	row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.accent:SetWidth(3)
	row.right = Theme.Text(row, Theme.F_SMALL, Theme.GOLD_LIGHT)
	row.right:SetPoint("RIGHT", row, "RIGHT", -P.right, 0)
	row.right:SetJustifyH("RIGHT")
	row.text = Theme.Text(row, Theme.F_SMALL, Theme.PARCHMENT)
	row.text:SetPoint("LEFT", row, "LEFT", row.forged and (XF.textLeft or P.textLeft) or 9, 0)
	row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
	row.text:SetJustifyH("LEFT")
	if row.text.SetWordWrap then row.text:SetWordWrap(false) end
	row:SetPoint("TOP", UIParent, "TOP", 0, P.y)
	row:Hide()
	return row
end

function ns:EnsureFeatPill()
	if self.featPill then return self.featPill end
	self.featPill = BuildPill()
	return self.featPill
end

local PillTick
function ns:FeatPillArm()
	if self.featPillHideAt or #self.featPills > 0 then ns.Every("quiet:pill", 0, PillTick) end
end

function ns:ShowNextFeatPill()
	local entry = table.remove(self.featPills, 1)
	if not entry then return nil end
	local pill = self:EnsureFeatPill()
	if not pill then self.featPills = {}; return nil end
	local left, right = self:FeatPillText(entry)
	pill.text:SetText(left)
	pill.right:SetText(right)
	pill.entry = entry
	pill:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, pill, 0.15) end
	self.featPillHideAt = Now() + ns.FEAT_PILL.life
	self:FeatPillArm()
	return pill
end

-- Une pastille : aucun son (pas d'onShow), aucune bulle, aucun bouton, et
-- jamais le créneau des bandeaux du haut
function ns:FeatPillPush(entry)
	if type(entry) ~= "table" then return false end
	table.insert(self.featPills, entry)
	if not self.featPillHideAt then self:ShowNextFeatPill() end
	self:FeatPillArm()
	return true
end

function ns:UpdateFeatPill(now)
	if self.featPillHideAt and now >= self.featPillHideAt then
		self.featPillHideAt = nil
		if self.featPill then self.featPill:Hide() end
	end
	if not self.featPillHideAt and #self.featPills > 0 then self:ShowNextFeatPill() end
end

PillTick = function()
	if not (ns.featPillHideAt or #ns.featPills > 0) then return false end
	local ok, err = pcall(ns.UpdateFeatPill, ns, Now())
	if not ok then
		ns.featPills, ns.featPillHideAt = {}, nil
		if ns.featPill then ns.featPill:Hide() end
		if ns.RecordError then ns:RecordError("quiet:pill", err) end
	end
	return (ns.featPillHideAt or #ns.featPills > 0) and true or false
end

-- ---------------------------------------------------------------------------
-- Signature : la patte du logo et « QUEST COMPANION », en haut à droite
-- ---------------------------------------------------------------------------
local function BuildSignature(frame)
	local S = ns.QC_SIGNATURE
	local sig = CreateFrame("Frame", nil, frame)
	if sig.EnableMouse then sig:EnableMouse(false) end
	local level = frame.GetFrameLevel and tonumber(frame:GetFrameLevel()) or 1
	if sig.SetFrameLevel then sig:SetFrameLevel(level + 36) end
	sig.text = Theme.Text(sig, Theme.F_CAPS, Theme.MUTED_LIGHT)
	sig.text:SetJustifyH("RIGHT")
	sig.text:SetText(L.QC_SIGNATURE)
	sig.text:SetPoint("RIGHT", sig, "RIGHT", 0, 0)
	sig.icon = sig:CreateTexture(nil, "OVERLAY")
	sig.icon:SetTexture(Theme.LOGO_GLYPH or Theme.LOGO_SMALL)
	sig.icon:SetSize(S.icon, S.icon)
	if sig.icon.SetDesaturated then pcall(sig.icon.SetDesaturated, sig.icon, true) end
	local m = Theme.MUTED_LIGHT
	sig.icon:SetVertexColor(m[1], m[2], m[3], 1)
	sig.icon:SetPoint("RIGHT", sig.text, "LEFT", -S.gap, 0)
	local w = Theme.TextWidth and tonumber(Theme.TextWidth(sig, L.QC_SIGNATURE, Theme.F_CAPS)) or (#L.QC_SIGNATURE * 6)
	sig:SetSize(math.ceil(w) + S.gap + S.icon, S.icon + 2)
	sig:Hide()
	return sig
end

-- Pose (ou retire) la signature d'un bandeau : à la hauteur de son petit
-- titre, contre le bord droit de la colonne de texte
function ns:SignatureSet(frame, on)
	if type(frame) ~= "table" then return nil end
	local sig = frame.qcSignature
	if not sig and not on then return nil end
	if not sig then
		sig = BuildSignature(frame)
		frame.qcSignature = sig
	end
	sig:ClearAllPoints()
	if frame.title then
		sig:SetPoint("TOPRIGHT", frame.title, "TOPRIGHT", 0, 1)
	else
		sig:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -9)
	end
	if on then sig:Show() else sig:Hide() end
	return on and sig or nil
end

-- ---------------------------------------------------------------------------
-- « Carte souvenir » : seulement quand l'étape 3 l'aura livrée (ns.SouvenirShow)
-- ---------------------------------------------------------------------------
function ns:SouvenirSync(frame, payload)
	if type(frame) ~= "table" then return nil end
	local button = frame.souvenirButton
	local share = frame.shareButton
	local on = payload ~= nil and type(ns.SouvenirShow) == "function" and share ~= nil and share:IsShown()
	if not on then
		if button then button:Hide() end
		return nil
	end
	if not button then
		button = self:ShareButton(frame, "souvenir")
		button:SetScript("OnEnter", nil)
		button:SetScript("OnLeave", nil)
		button:SetScript("OnClick", function(b) if type(ns.SouvenirShow) == "function" then pcall(ns.SouvenirShow, ns, b.payload) end end)
		frame.souvenirButton = button
	end
	button.payload = payload
	if button.label then
		button.label:SetText(L.SOUVENIR_BUTTON)
		button.label:Show()
		local measure = button.label.GetUnboundedStringWidth or button.label.GetStringWidth
		local B = ns.SHARE_BUTTON
		button:SetWidth(B.size + B.labelGap + math.ceil(tonumber(measure and measure(button.label)) or 80) + B.labelPad)
	end
	local level = share.GetFrameLevel and share:GetFrameLevel() or 1
	if button.SetFrameLevel then button:SetFrameLevel(level) end
	button:ClearAllPoints()
	button:SetPoint("RIGHT", share, "LEFT", -6, 0)
	button:Show()
	return button
end

-- ---------------------------------------------------------------------------
-- Branchements : bandeau du carnet (grand haut fait), « Capturé ! »
-- ---------------------------------------------------------------------------
do
	local base = ns.ShowNextJournalToast
	if base then
		function ns:ShowNextJournalToast(...)
			local frame = base(self, ...)
			if frame then
				local entry = frame.entry
				local big = type(entry) == "table" and entry.kind == "feat" and entry.big == true and not entry.retro
				local ok, err = pcall(self.SignatureSet, self, frame, big)
				if not ok and self.RecordError then self:RecordError("quiet:signature", err) end
				ok, err = pcall(self.SouvenirSync, self, frame, big and { kind = "feat", entry = entry } or nil)
				if not ok and self.RecordError then self:RecordError("quiet:souvenir", err) end
			end
			return frame
		end
	end
end

-- La ligne de la cote sous les étoiles du « Capturé ! » (créée à la première)
local function OddsLine(frame)
	if frame.odds then return frame.odds end
	if frame.forgeBanner and ns.ForgeBannerLine and frame.text then
		local width = tonumber(frame.text.GetWidth and frame.text:GetWidth()) or 240
		frame.odds = ns.ForgeBannerLine(frame, Theme.F_SMALL, Theme.PARCHMENT, width)
		if frame.shareWidths and frame.shareWidths.text then frame.shareWidths.odds = frame.shareWidths.text end
	else
		local fs = Theme.Text(frame, Theme.F_SMALL, Theme.PARCHMENT)
		fs:SetPoint("TOPLEFT", frame.stars or frame.text, "BOTTOMLEFT", 0, -3)
		fs:SetWidth(tonumber(frame.stars and frame.stars:GetWidth()) or 240)
		fs:SetJustifyH("LEFT")
		if fs.SetWordWrap then fs:SetWordWrap(false) end
		frame.odds = fs
		frame.oddsBaseH = tonumber(frame:GetHeight()) or 66
	end
	return frame.odds
end

function ns:CaptureResultRare(frame, result)
	if type(frame) ~= "table" or type(result) ~= "table" then return nil end
	local spec = result.specimen
	if type(spec) ~= "table" and spec ~= nil and self.SpecimenGet then spec = self:SpecimenGet(spec) end
	if type(spec) == "table" and result.shiny and not spec.shiny then
		local copy = {}
		for k, v in pairs(spec) do copy[k] = v end
		copy.shiny = true
		spec = copy
	end
	local text = type(spec) == "table" and self:SpecimenOddsText(spec) or nil
	if text or frame.odds then
		local line = OddsLine(frame)
		line:SetText(text or "")
		if frame.forgeBanner then
			local keys = { "title", "text", "stars", "odds" }
			if self.ForgeBannerStack then self:ForgeBannerStack(frame, keys, ns.FORGE_RESULT and ns.FORGE_RESULT.h) end
		else
			if text then line:Show() else line:Hide() end
			frame:SetHeight((frame.oddsBaseH or 66) + (text and 14 or 0))
		end
	end
	frame.oddsShown = text
	local rare = result.shiny == true or text ~= nil
	self:SignatureSet(frame, rare)
	self:SouvenirSync(frame, rare and { kind = "capture", result = result } or nil)
	return text
end

do
	local base = ns.CaptureResultShow
	if base then
		function ns:CaptureResultShow(result, ...)
			local frame = base(self, result, ...)
			if frame then
				local ok, err = pcall(self.CaptureResultRare, self, frame, result)
				if not ok and self.RecordError then self:RecordError("quiet:result", err) end
			end
			return frame
		end
	end
end

-- ---------------------------------------------------------------------------
-- L'indice d'un secret : au repos, une fois par semaine, créneau des astuces
-- ---------------------------------------------------------------------------
-- La clé de texte de l'indice à dire maintenant, ou nil
function ns:QuietHintPick()
	if self:Quiet() then return nil end
	if not Call("IsResting") then return nil end
	local db = self:DB()
	local last = tonumber(db.quietHintAt)
	if last and Wall() - last < ns.QUIET_HINT_GAP then return nil end
	if not self.FeatHintNext then return nil end
	local text, id = self:FeatHintNext()
	if not (text and id) then return nil end
	local key = "FEATH_" .. tostring(id)
	-- (un secret sans texte d'indice : rien à dire de la bouche du compagnon)
	if L[key] == key or L[key] == nil then return nil end
	return key
end

do
	local pick = ns.DiscoveryPick
	if pick then
		function ns:DiscoveryPick(...)
			local ok, key = pcall(self.QuietHintPick, self)
			if ok and key then return { id = ns.QUIET_HINT_ID, line = key, hint = true } end
			return pick(self, ...)
		end
	end
	local shown = ns.DiscoveryShown
	if shown then
		function ns:DiscoveryShown(tip, ...)
			if type(tip) == "table" and tip.hint then
				self:DB().quietHintAt = Wall()
				self.discoveryBubble = nil
				return
			end
			return shown(self, tip, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Réglages : la ligne « Mode discret » mise en avant (liseré ambre)
-- ---------------------------------------------------------------------------
do
	local base = ns.RefreshOptions
	if base then
		function ns:RefreshOptions(...)
			local result = base(self, ...)
			local frame = self.optionsFrame
			for _, card in ipairs((frame and frame.rows) or {}) do
				if card.def and card.def.key == "quiet" and not card.quietEdge and Theme.Border then
					card.quietEdge = Theme.Border(card, Theme.GOLD, 1)
				end
			end
			return result
		end
	end
end

if ns.Mark then ns.Mark("Quiet") end
