-- CaptureBatch.lua -- « Tout capturer » : le filet sur toute la file d'un coup (QuestCompanion 2.4.0)
--
-- Retour des joueurs : après un pack, cinq ou six créatures attendent dans
-- le filet, et il faut cliquer, regarder la scène, recliquer… Désormais,
-- dès que deux candidats attendent, « Tout capturer » (liste du clic droit,
-- bandeau « Capture possible », /qc filet tout) les tente tous :
--   * chaque essai suit les règles d'un lancer seul : même tirage
--     (ns:CaptureRoll, Capture.lua), même verdict par ns:CaptureResolve et
--     toutes ses enveloppes (étoiles, aides rendues, sceaux, missions,
--     tutoriel…). Rien n'est recopié ici ;
--   * les verdicts tombent TOUS d'abord et sont enregistrés tout de suite ;
--     la scène ne fait que les montrer : une grille de cartes face cachée,
--     retournées en vague diagonale, les brillantes gardées pour la fin, de
--     la plus modeste à la plus belle ;
--   * l'aide choisie sert à chaque essai, comme pour un lancer seul ; s'il
--     n'en reste pas assez pour tous, on tente ceux qu'elle couvre (dans
--     l'ordre de la file) et les autres restent dans le filet ;
--   * jamais en combat.
-- Les messages du chat et les bulles du compagnon que les verdicts
-- produiraient sont retenus pendant le tirage : le chat ne gâche pas la
-- surprise, il reçoit tout à la fin de la scène (ou à « Arrêter », Échap).
-- La scène : une seule fenêtre, une horloge OnUpdate (pas d'AnimationGroup),
-- rien d'alloué à chaque image ; nos textures (Textures/) et les aplats du
-- thème, jamais d'art de Blizzard.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_BATCH_MIN = 2            -- candidats à partir desquels « Tout capturer » se propose
ns.CAPTURE_BATCH_FLIP = 0.26        -- s pour retourner une carte
ns.CAPTURE_BATCH_LEAD = 0.35        -- s avant la vague (la grille se pose)
ns.CAPTURE_BATCH_WAVE = 1.5         -- s de la première à la dernière carte de la vague
ns.CAPTURE_BATCH_PAUSE = 0.5        -- s de silence avant les cartes gardées pour la fin
ns.CAPTURE_BATCH_SPECIAL_GAP = 0.85 -- s entre deux cartes gardées pour la fin…
ns.CAPTURE_BATCH_SPECIAL_SPAN = 3   -- … resserré pour qu'elles tiennent toutes en 3 s environ
ns.CAPTURE_BATCH_SPECIAL_MIN = 0.35 -- (jamais moins de 0,35 s : chacune a son moment)
ns.CAPTURE_BATCH_SOUND_GAP = 0.06   -- s au moins entre deux bruits de carte
ns.CAPTURE_BATCH_COLS = 4
-- le bruit d'une carte qui se retourne : IG_ABILITY_PAGE_TURN (kit du client)
if type(ns.CAPTURE_SOUNDS) == "table" and not ns.CAPTURE_SOUNDS.flip then ns.CAPTURE_SOUNDS.flip = 836 end

local TILE_W, TILE_H, TILE_GAP = 96, 120, 8
local PAD, HEAD, FOOT, MIN_W = 16, 44, 48, 340
local GLYPH = 40
local RANK_ORDER = { trivial = 0, minus = 0, normal = 1, elite = 2, rare = 3, rareelite = 4, worldboss = 5 }

local FR = {
	CAPTURE_BATCH_ACTION   = "Tout capturer",
	CAPTURE_BATCH_TIP      = "Lance le filet sur toutes les créatures qui attendent, d'un coup. Chaque essai compte comme un lancer (et coûte l'aide choisie).",
	CAPTURE_BATCH_TITLE    = "Tout capturer",
	CAPTURE_BATCH_COUNT    = "Captures : %d",
	CAPTURE_BATCH_STOP     = "Arrêter",
	CAPTURE_BATCH_CLOSE    = "Fermer",
	CAPTURE_BATCH_FLED     = "échappée",
	CAPTURE_BATCH_NEW      = "Nouvelle",
	CAPTURE_BATCH_SHINY    = "Brillante",
	CAPTURE_BATCH_BETTER   = "Mieux",
	CAPTURE_BATCH_RUNNING  = "Résultats déjà enregistrés : Arrêter montre tout.",
	CAPTURE_BATCH_DONE     = "Résultats enregistrés · Échap pour fermer",
	CAPTURE_BATCH_SUMMARY  = "Tout capturer : %d capturées sur %d essais.",
	CAPTURE_BATCH_SUMMARY_SHINY = "Tout capturer : %d capturées sur %d essais, dont %d brillantes !",
	CAPTURE_BATCH_SHORT    = "Plus assez de %s : %d essais sur %d, les autres restent dans le filet.",
	CAPTURE_BATCH_COMBAT   = "Pas de capture en combat : le filet attend la fin du combat.",
	CAPTURE_BATCH_BUSY     = "Un filet est déjà lancé : attends son verdict.",
}
local EN = {
	CAPTURE_BATCH_ACTION   = "Capture all",
	CAPTURE_BATCH_TIP      = "Throws the net at every creature waiting, all at once. Each try counts as a throw (and uses the chosen aid).",
	CAPTURE_BATCH_TITLE    = "Capture all",
	CAPTURE_BATCH_COUNT    = "Captures: %d",
	CAPTURE_BATCH_STOP     = "Stop",
	CAPTURE_BATCH_CLOSE    = "Close",
	CAPTURE_BATCH_FLED     = "got away",
	CAPTURE_BATCH_NEW      = "New",
	CAPTURE_BATCH_SHINY    = "Shiny",
	CAPTURE_BATCH_BETTER   = "Better",
	CAPTURE_BATCH_RUNNING  = "Results already saved: Stop shows them all.",
	CAPTURE_BATCH_DONE     = "Results saved · Escape to close",
	CAPTURE_BATCH_SUMMARY  = "Capture all: %d captured out of %d tries.",
	CAPTURE_BATCH_SUMMARY_SHINY = "Capture all: %d captured out of %d tries, %d of them shiny!",
	CAPTURE_BATCH_SHORT    = "Out of %s: %d tries out of %d, the others stay in the net.",
	CAPTURE_BATCH_COMBAT   = "No capturing in combat: the net waits for the fight to end.",
	CAPTURE_BATCH_BUSY     = "A net is already out: wait for its verdict.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_BATCH_STRINGS = { fr = FR, en = EN } end

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
local function Tint(region, c, alpha) if region and c then region:SetVertexColor(c[1], c[2], c[3], alpha or 1) end end

-- Pendant le tirage, les verdicts ne font pas de bruit : la scène joue les
-- sons au retournement des cartes
do
	local base = ns.CapturePlaySound
	if base then
		function ns:CapturePlaySound(key, ...)
			if self.captureBatchResolving then return false end
			return base(self, key, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Le tirage : tous les verdicts, enregistrés d'un coup
-- ---------------------------------------------------------------------------
-- « Tout capturer » est-il proposé ? (au moins CAPTURE_BATCH_MIN candidats)
function ns:CaptureBatchOffered()
	if not Enabled() then return false end
	local queue = self.captureState and self.captureState.queue
	return queue ~= nil and #queue >= ns.CAPTURE_BATCH_MIN
end

-- Force d'un résultat : sert à garder le plus beau pour la fin
local function Strength(result)
	local target = result.target
	return (target.shiny and 1000 or 0) + (result.fresh and 100 or 0)
		+ (RANK_ORDER[target.class] or 1) * 10 + (tonumber(result.stars) or 0)
end
-- Une brillante capturée : retournée à la fin (les espèces nouvelles, la
-- plupart du filet, se retournent dans la vague : elle garde son effet)
local function Special(result)
	return result.success and result.target.shiny and true or false
end
ns.CaptureBatchStrength, ns.CaptureBatchSpecial = Strength, Special

-- Tente toute la file (dans son ordre de priorité). Renvoie le lot
-- { results, tried, total, short, aid } et ouvre la scène, ou nil et la
-- raison ("off", "combat", "busy", "empty").
function ns:CaptureBatch()
	if not Enabled() then return nil, "off" end
	if InCombat() then self:Print(L.CAPTURE_BATCH_COMBAT); return nil, "combat" end
	local state = self:CaptureState()
	self:CaptureHideQueueList()
	-- le verdict d'un lancer seul est encore à l'écran : on le referme
	if state.rolling and state.rolling.result then
		state.rolling.closeAt = Clock()
		self:CaptureTick(Clock())
	end
	if state.rolling then self:Print(L.CAPTURE_BATCH_BUSY); return nil, "busy" end
	-- un lot encore à l'écran : il se montre d'un coup avant le suivant
	if self.captureBatch and not self.captureBatch.done then self:CaptureBatchStop(true) end
	local queue = self:CaptureQueuePrune()
	if #queue == 0 then self:Print(L.CAPTURE_Q_NOTHING); return nil, "empty" end
	local picked = {}
	for index, candidate in ipairs(queue) do picked[index] = candidate end
	local aid = state.aid
	if aid and self:CaptureAidCount(aid) <= 0 then aid, state.aid = nil, nil end
	-- le tutoriel de la ménagerie attendait le filet (avant que la file ne se vide)
	if self.CompanionSequenceAdvance then pcall(self.CompanionSequenceAdvance, self, "net") end
	self:CaptureToastHide()
	self:CapturePlaySound("throw")

	local batch = { results = {}, total = #picked, aid = aid, messages = {}, startedAt = Clock() }
	-- chat et bulles retenus jusqu'à la fin de la scène
	local print, say = self.Print, self.CompanionSay
	self.Print = function(_, ...) batch.messages[#batch.messages + 1] = { ... } end
	self.CompanionSay = function() return false, "batch" end
	self.captureBatchResolving = true
	local ok, err = pcall(function()
		for _, candidate in ipairs(picked) do
			-- une capture précédente du lot a pu lui ôter son intérêt (même
			-- espèce, déjà à 3 étoiles) : il sort du filet sans essai
			if not self:CaptureQueueReason(candidate) then
				self:CaptureQueueRemove(candidate)
			else
				-- l'aide manque : les suivants restent dans le filet
				if aid and self:CaptureAidCount(aid) <= 0 then batch.short = true; break end
				self:CaptureQueueRemove(candidate)
				local target = {}
				for key, value in pairs(candidate) do target[key] = value end
				target.expires = nil
				local shiny = target.shiny and true or false
				local fresh = not self:CaptureIsCaptured(target.npcID)
				local before = self:CaptureStars(target.npcID, shiny)
				local rolling = self:CaptureRoll(target, aid)
				rolling.batch = true
				rolling.result = rolling.success and "ok" or "fail"
				local done, why = pcall(self.CaptureResolve, self, rolling)
				if not done and self.RecordError then self:RecordError("capture:batch", why) end
				batch.results[#batch.results + 1] = {
					target = target, success = rolling.success and true or false, stars = rolling.stars,
					better = rolling.starsBetter, before = before, fresh = fresh, aid = rolling.aid,
				}
			end
		end
	end)
	self.captureBatchResolving = nil
	self.Print, self.CompanionSay = print, say
	if not ok and self.RecordError then self:RecordError("capture:batch", err) end
	batch.tried = #batch.results
	if batch.short then
		batch.messages[#batch.messages + 1] = { self:F("CAPTURE_BATCH_SHORT", self:CaptureAidLabel(aid), batch.tried, batch.total) }
	end
	self:CaptureQueueRefresh()
	self.captureBatch = batch
	if batch.tried == 0 then
		batch.done = true
		self:CaptureBatchFlush(batch)
		return batch
	end
	self:CaptureBatchShow(batch)
	return batch
end

-- Ce qui a été retenu pendant le tirage : les messages, un bilan, une bulle
-- du compagnon (la plus belle prise), et la suite du tutoriel
function ns:CaptureBatchFlush(batch)
	if not batch or batch.flushed then return end
	batch.flushed = true
	for _, message in ipairs(batch.messages) do self:Print(unpack(message)) end
	local got, shinies, best = 0, 0, nil
	for _, result in ipairs(batch.results) do
		if result.success then
			got = got + 1
			if result.target.shiny then shinies = shinies + 1 end
			if not best or Strength(result) > Strength(best) then best = result end
		end
	end
	batch.got = got
	if batch.tried > 0 then
		self:Print(shinies > 0 and self:F("CAPTURE_BATCH_SUMMARY_SHINY", got, batch.tried, shinies)
			or self:F("CAPTURE_BATCH_SUMMARY", got, batch.tried))
		if best then
			self:CompanionSay(best.target.shiny and "CAPTURE_SHINY" or "CAPTURE_OK", { force = true, args = { best.target.name } })
		else
			local last = batch.results[#batch.results]
			self:CompanionSay("CAPTURE_FAIL", { force = true, args = { last and last.target.name or "" } })
		end
	end
	-- la scène est « refermée » pour le tutoriel de la ménagerie (Companion.lua)
	if self.CompanionSequenceAdvance then pcall(self.CompanionSequenceAdvance, self, "stage", { ok = got > 0 }) end
end

-- ---------------------------------------------------------------------------
-- La scène : une grille de cartes face cachée
-- ---------------------------------------------------------------------------
local function Art() return ns.CAPTURE_ART or {} end

local function CreateTile(parent)
	local tile = CreateFrame("Frame", nil, parent)
	tile:SetSize(TILE_W, TILE_H)
	tile.bg = Theme.Solid(tile, "BACKGROUND", Theme.NAV or Theme.WINDOW, 1)
	tile.bg:SetAllPoints()
	tile.edge = Theme.Border(tile, Theme.GOLD_SOFT or Theme.GOLD, 1)
	-- le halo d'une carte gardée pour la fin (notre texture, en ADD)
	tile.halo = tile:CreateTexture(nil, "BACKGROUND", nil, 2)
	tile.halo:SetTexture(Art().halo or "Interface\\Buttons\\WHITE8X8")
	if tile.halo.SetBlendMode then pcall(tile.halo.SetBlendMode, tile.halo, "ADD") end
	tile.halo:SetPoint("TOPLEFT", tile, "TOPLEFT", 4, -4)
	tile.halo:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -4, 4)
	tile.halo:Hide()
	-- le dos : le glyphe du filet, ambre
	tile.glyph = tile:CreateTexture(nil, "ARTWORK")
	tile.glyph:SetTexture(Art().icon or "Interface\\Icons\\Spell_Nature_Web")
	tile.glyph:SetSize(GLYPH, GLYPH)
	tile.glyph:SetPoint("CENTER", tile, "CENTER", 0, 0)
	-- la face : filet de rareté en haut, étiquette, nom, étoiles
	tile.bar = Theme.Solid(tile, "BORDER", { 1, 1, 1 }, 1)
	tile.bar:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
	tile.bar:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -1, -1)
	tile.bar:SetHeight(3)
	tile.tag = Theme.Text(tile, Theme.F_CAPS or Theme.F_SMALL, Theme.GOLD)
	tile.tag:SetPoint("TOP", tile, "TOP", 0, -12)
	tile.name = Theme.Text(tile, Theme.F_LABEL or Theme.F_SMALL, Theme.PARCHMENT)
	tile.name:SetPoint("CENTER", tile, "CENTER", 0, 6)
	tile.name:SetWidth(TILE_W - 10)
	tile.name:SetJustifyH("CENTER")
	tile.stars = Theme.Text(tile, Theme.F_SMALL, Theme.PARCHMENT)
	tile.stars:SetPoint("BOTTOM", tile, "BOTTOM", 0, 14)
	tile.stars:SetJustifyH("CENTER")
	return tile
end

-- Les détails de la face (textes) : cachés pendant que la carte tourne
local function Details(tile, shown)
	for _, region in ipairs({ tile.tag, tile.name, tile.stars }) do
		if shown then region:Show() else region:Hide() end
	end
end

-- Face cachée
local function ApplyBack(tile)
	tile.facing = "back"
	Tint(tile.bg, Theme.NAV or Theme.WINDOW, 1)
	if tile.edge and tile.edge.SetColor then local c = Theme.GOLD_SOFT or Theme.GOLD; tile.edge:SetColor(c[1], c[2], c[3], 1) end
	tile.glyph:Show()
	Tint(tile.glyph, Theme.GOLD, 0.85)
	tile.bar:Hide()
	tile.halo:Hide()
	Details(tile, false)
end

-- Face visible : le verdict de `result`
local function ApplyFront(self, tile, result)
	tile.facing = "front"
	tile.glyph:Hide()
	local target = result.target
	if result.success then
		local rarity = self.CaptureRarity and self:CaptureRarity(target) or { color = Theme.PARCHMENT }
		local c = rarity.color
		Tint(tile.bg, Theme.ROW or Theme.WINDOW, 1)
		if tile.edge and tile.edge.SetColor then tile.edge:SetColor(c[1], c[2], c[3], 1) end
		tile.bar:Show()
		Tint(tile.bar, c, 1)
		tile.name:SetText(target.name)
		tile.name:SetTextColor(c[1], c[2], c[3])
		tile.stars:SetText(self:CaptureStarsText(result.stars or 1, 14))
		local tag = target.shiny and L.CAPTURE_BATCH_SHINY or (result.fresh and L.CAPTURE_BATCH_NEW)
			or (result.before and result.better and L.CAPTURE_BATCH_BETTER) or ""
		tile.tag:SetText(Theme.Upper and Theme.Upper(tag) or tag)
		local tc = target.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD
		tile.tag:SetTextColor(tc[1], tc[2], tc[3])
		if Special(result) then
			Tint(tile.halo, target.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or c, 0.5)
			tile.halo:Show()
		else
			tile.halo:Hide()
		end
	else
		Tint(tile.bg, Theme.NAV or Theme.WINDOW, 1)
		local e = Theme.EDGE or Theme.MUTED
		if tile.edge and tile.edge.SetColor then tile.edge:SetColor(e[1], e[2], e[3], 1) end
		tile.bar:Hide()
		tile.halo:Hide()
		tile.name:SetText(target.name)
		tile.name:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		tile.stars:SetText(L.CAPTURE_BATCH_FLED)
		tile.stars:SetTextColor(Theme.RED[1], Theme.RED[2], Theme.RED[3])
		tile.tag:SetText("")
	end
	if result.success then tile.stars:SetTextColor(1, 1, 1) end
end

function ns:EnsureCaptureBatchFrame()
	if self.captureBatchFrame then return self.captureBatchFrame end
	if not (Theme and Theme.CreateToast) then return nil end
	-- un nom global : Échap la referme (UISpecialFrames), comme la scène d'un lancer seul
	local frame = Theme.CreateToast(UIParent, MIN_W, 300, { strata = "DIALOG", name = "QuestCompanionCaptureBatch", accent = Theme.GOLD })
	if not frame then return nil end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	frame:EnableMouse(true)
	if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
	-- cachée (Échap, ×, Fermer) : tout ce qui restait se montre d'un coup
	-- (les verdicts sont déjà enregistrés), le chat reçoit ses messages
	frame:SetScript("OnHide", function()
		local batch = ns.captureBatch
		if batch and not batch.done then ns:CaptureBatchStop(true) end
	end)
	local left = frame.contentLeft or PAD
	frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -12)
	frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_BATCH_TITLE) or L.CAPTURE_BATCH_TITLE)
	frame.counter = Theme.Text(frame, Theme.F_TITLE or Theme.F_LABEL, Theme.PARCHMENT)
	frame.counter:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -24)
	if Theme.CreateCloseButton then
		frame.close = Theme.CreateCloseButton(frame, 18)
		frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	end
	-- l'aide utilisée, en badge sous le ×
	frame.aidIcon = frame:CreateTexture(nil, "OVERLAY")
	frame.aidIcon:SetSize(14, 14)
	frame.aidIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.aidText = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
	frame.aidText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -30)
	frame.aidText:SetJustifyH("RIGHT")
	frame.aidIcon:SetPoint("RIGHT", frame.aidText, "LEFT", -4, 0)
	frame.grid = CreateFrame("Frame", nil, frame)
	frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEAD)
	frame.grid:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -HEAD)
	frame.grid:SetHeight(TILE_H)
	frame.tiles = {}
	frame.stop = Theme.CreateButton(frame, "auto", Theme.DIALOG_BUTTON_HEIGHT or 28, L.CAPTURE_BATCH_STOP, function()
		local batch = ns.captureBatch
		if batch and not batch.done then ns:CaptureBatchStop() else frame:Hide() end
	end)
	frame.stop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
	frame.footer = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
	frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 18)
	frame.footer:SetJustifyH("LEFT")
	if frame.footer.SetWordWrap then frame.footer:SetWordWrap(false) end
	frame:SetScript("OnUpdate", function()
		local done, err = pcall(ns.CaptureBatchUpdate, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("capture:batch:scene", err) end
	end)
	frame:Hide()
	self.captureBatchFrame = frame
	return frame
end

-- Taille de la grille pour `n` cartes : colonnes, rangées
function ns:CaptureBatchGrid(n)
	local cols = math.max(1, math.min(n, ns.CAPTURE_BATCH_COLS))
	return cols, math.max(1, math.ceil(n / cols))
end

-- L'ordre de retournement : la vague diagonale (haut gauche -> bas droite)
-- pour les cartes ordinaires, puis les cartes gardées, de la plus modeste
-- à la plus belle. Pose card.flipAt (relatif au début de la scène).
function ns:CaptureBatchSchedule(batch)
	local cols, rows = self:CaptureBatchGrid(#batch.cards)
	local span = math.max(1, (cols - 1) + (rows - 1) * 1.4)
	local wave, special = {}, {}
	for index, card in ipairs(batch.cards) do
		if Special(card.result) then
			special[#special + 1] = card
		else
			local col, row = (index - 1) % cols, math.floor((index - 1) / cols)
			card.flipAt = ns.CAPTURE_BATCH_LEAD + (col + row * 1.4) / span * ns.CAPTURE_BATCH_WAVE
			wave[#wave + 1] = card
		end
	end
	table.sort(wave, function(a, b)
		if a.flipAt ~= b.flipAt then return a.flipAt < b.flipAt end
		return a.index < b.index
	end)
	table.sort(special, function(a, b)
		local sa, sb = Strength(a.result), Strength(b.result)
		if sa ~= sb then return sa < sb end
		return a.index < b.index
	end)
	local at = ns.CAPTURE_BATCH_LEAD + (#wave > 0 and (ns.CAPTURE_BATCH_WAVE + ns.CAPTURE_BATCH_FLIP + ns.CAPTURE_BATCH_PAUSE) or 0)
	-- (un pack de nouveautés : l'écart se resserre, sans tomber sous le minimum)
	local gap = math.max(ns.CAPTURE_BATCH_SPECIAL_MIN,
		math.min(ns.CAPTURE_BATCH_SPECIAL_GAP, ns.CAPTURE_BATCH_SPECIAL_SPAN / math.max(1, #special)))
	for _, card in ipairs(special) do
		card.flipAt = at
		card.special = true
		at = at + gap
	end
	-- l'ordre complet, pour les tests et le relevé
	local order = {}
	for _, card in ipairs(wave) do order[#order + 1] = card end
	for _, card in ipairs(special) do order[#order + 1] = card end
	batch.order = order
	return order
end

function ns:CaptureBatchShow(batch)
	local frame = self:EnsureCaptureBatchFrame()
	if not (frame and batch) then return nil end
	local n = #batch.results
	local cols, rows = self:CaptureBatchGrid(n)
	local gridW = cols * TILE_W + (cols - 1) * TILE_GAP
	local gridH = rows * TILE_H + (rows - 1) * TILE_GAP
	frame:SetSize(math.max(MIN_W, gridW + 2 * PAD), HEAD + gridH + FOOT)
	frame.grid:SetHeight(gridH)
	batch.cards = {}
	for index = 1, math.max(n, #frame.tiles) do
		local tile = frame.tiles[index]
		if index <= n then
			if not tile then tile = CreateTile(frame.grid); frame.tiles[index] = tile end
			local col, row = (index - 1) % cols, math.floor((index - 1) / cols)
			-- ancrée par son centre : en rétrécissant, la carte tourne sur elle-même
			tile:ClearAllPoints()
			tile:SetPoint("CENTER", frame.grid, "TOP", -gridW / 2 + TILE_W / 2 + col * (TILE_W + TILE_GAP),
				-(TILE_H / 2 + row * (TILE_H + TILE_GAP)))
			tile:SetWidth(TILE_W)
			ApplyBack(tile)
			tile:Show()
			batch.cards[index] = { index = index, tile = tile, result = batch.results[index] }
		elseif tile then
			tile:Hide()
		end
	end
	self:CaptureBatchSchedule(batch)
	batch.shown, batch.revealed, batch.soundAt = 0, 0, nil
	batch.startedAt = Clock()
	frame.counter:SetText(self:F("CAPTURE_BATCH_COUNT", 0))
	local aid
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == batch.aid then aid = def end end
	if aid then
		frame.aidIcon:SetTexture(aid.icon)
		frame.aidText:SetText(tostring(self:CaptureAidLabel(aid.id)))
		frame.aidIcon:Show(); frame.aidText:Show()
	else
		frame.aidIcon:Hide(); frame.aidText:Hide()
	end
	frame.stop:SetText(L.CAPTURE_BATCH_STOP)
	frame.footer:SetText(L.CAPTURE_BATCH_RUNNING)
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	-- capture animée coupée (réglage) : tout se montre d'emblée
	if self.CaptureStageOn and not self:CaptureStageOn() then self:CaptureBatchStop() end
	return frame
end

-- Une carte vient de montrer sa face : compteur, son d'une carte gardée
local function Faced(self, batch, card)
	card.faced = true
	ApplyFront(self, card.tile, card.result)
	Details(card.tile, false)
	if card.result.success then
		batch.shown = batch.shown + 1
		local frame = self.captureBatchFrame
		if frame then frame.counter:SetText(self:F("CAPTURE_BATCH_COUNT", batch.shown)) end
	end
	if card.special and not batch.quick then
		self:CapturePlaySound(card.result.target.shiny and "shiny" or "ok")
	end
end

local function Revealed(batch, card)
	card.revealed = true
	card.tile:SetWidth(TILE_W)
	Details(card.tile, true)
	batch.revealed = batch.revealed + 1
end

-- L'horloge de la scène (OnUpdate) : chaque carte se retourne à son heure,
-- largeur = W·|cos(π·e)|, la face change à mi-course
function ns:CaptureBatchUpdate(now)
	local batch = self.captureBatch
	if not (batch and batch.cards) or batch.done then return nil end
	local t = now - (batch.startedAt or now)
	local flip = ns.CAPTURE_BATCH_FLIP
	for _, card in ipairs(batch.order) do
		if not card.revealed then
			if not card.flipStart and t >= card.flipAt then
				card.flipStart = now
				-- un bruit de carte, pas plus d'un toutes les 0,06 s
				if not card.special and (not batch.soundAt or now - batch.soundAt >= ns.CAPTURE_BATCH_SOUND_GAP) then
					if self:CapturePlaySound("flip") then batch.soundAt = now end
				end
			end
			if card.flipStart then
				local e = (now - card.flipStart) / flip
				if e >= 0.5 and not card.faced then Faced(self, batch, card) end
				if e >= 1 then
					Revealed(batch, card)
				else
					card.tile:SetWidth(math.max(1, TILE_W * math.abs(math.cos(math.pi * e))))
					if card.faced and e >= 0.8 then Details(card.tile, true) end
				end
			end
		end
	end
	-- les cartes gardées battent doucement une fois retournées
	for _, card in ipairs(batch.cards) do
		if card.special and card.faced then card.tile.halo:SetAlpha(0.35 + 0.25 * math.abs(math.sin(now * 2.5))) end
	end
	if batch.revealed >= #batch.cards then self:CaptureBatchFinish() end
	return batch.revealed
end

-- Fin de la scène : tout est retourné ; le chat reçoit ses messages
function ns:CaptureBatchFinish()
	local batch = self.captureBatch
	if not batch or batch.done then return false end
	batch.done = true
	-- rien de beau dans le lot : le petit son d'échec, une fois
	local any = false
	for _, result in ipairs(batch.results) do if result.success then any = true end end
	if not any and not batch.silent then self:CapturePlaySound("fail") end
	local frame = self.captureBatchFrame
	if frame then
		frame.stop:SetText(L.CAPTURE_BATCH_CLOSE)
		frame.footer:SetText(L.CAPTURE_BATCH_DONE)
	end
	self:CaptureBatchFlush(batch)
	return true
end

-- « Arrêter » : toutes les cartes encore cachées se retournent d'un coup
-- (les verdicts sont déjà enregistrés). quiet : sans son (Échap, nouveau lot)
function ns:CaptureBatchStop(quiet)
	local batch = self.captureBatch
	if not batch or batch.done then return false end
	batch.quick = true
	batch.silent = quiet and true or nil
	local best
	for _, card in ipairs(batch.cards or {}) do
		if not card.revealed then
			if not card.faced then
				Faced(self, batch, card)
				if card.special and (not best or Strength(card.result) > Strength(best)) then best = card.result end
			end
			Revealed(batch, card)
		end
	end
	-- la plus belle des cartes qui restaient : sa fanfare, une seule
	if best and not quiet then self:CapturePlaySound(best.target.shiny and "shiny" or "ok") end
	self:CaptureBatchFinish()
	return true
end

function ns:CaptureBatchHide()
	if self.captureBatchFrame then self.captureBatchFrame:Hide() end
end

-- ---------------------------------------------------------------------------
-- Les entrées : la liste du filet, le bandeau, /qc filet tout
-- ---------------------------------------------------------------------------
local function ShowTip(button, text)
	local tooltip = Tooltip()
	if not tooltip then return end
	tooltip:SetOwner(button, "ANCHOR_TOP")
	Theme.TooltipLine(tooltip, L.CAPTURE_BATCH_ACTION, Theme.PARCHMENT)
	Theme.TooltipLine(tooltip, text, Theme.MUTED_LIGHT)
	tooltip:Show()
end
local function HideTip() local t = Tooltip(); if t and t.Hide then t:Hide() end end

-- Bouton compact : le libellé et un peu d'air
local function CompactWidth(parent, label)
	local w = Theme.TextWidth and Theme.TextWidth(parent, label, Theme.F_LABEL) or 60
	return math.max(36, math.ceil((tonumber(w) or 60) + 16))
end

-- La liste (clic droit sur le filet) : « Tout capturer » en haut, à gauche du ×
do
	local ensure = ns.EnsureCaptureQueueList
	if ensure then
		function ns:EnsureCaptureQueueList(...)
			local fresh = not self.captureQueueList
			local frame = ensure(self, ...)
			if frame and fresh and not frame.all then
				local button = Theme.CreateButton(frame, CompactWidth(frame, L.CAPTURE_BATCH_ACTION), 18, L.CAPTURE_BATCH_ACTION,
					function() ns:CaptureHideQueueList(); ns:CaptureBatch() end, "accent")
				if frame.close then
					button:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
				else
					button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
				end
				button:SetScript("OnEnter", function(b) ShowTip(b, L.CAPTURE_BATCH_TIP) end)
				button:SetScript("OnLeave", HideTip)
				button:Hide()
				frame.all = button
			end
			return frame
		end
	end
	local refresh = ns.CaptureRefreshQueueList
	if refresh then
		function ns:CaptureRefreshQueueList(...)
			local a, b = refresh(self, ...)
			local frame = self.captureQueueList
			if frame and frame.all then
				if self:CaptureBatchOffered() then frame.all:Show() else frame.all:Hide() end
			end
			return a, b
		end
	end
end

-- Le bandeau « Capture possible » : « Tout capturer » à gauche d'Ignorer,
-- dans la rangée du bas (l'aide garde sa ligne au-dessus)
do
	local ensure = ns.EnsureCaptureToast
	if ensure then
		function ns:EnsureCaptureToast(...)
			local fresh = not self.captureToast
			local frame = ensure(self, ...)
			if frame and fresh and not frame.all and frame.ignore then
				local button = Theme.CreateButton(frame, CompactWidth(frame, L.CAPTURE_BATCH_ACTION), 18, L.CAPTURE_BATCH_ACTION,
					function() ns:CaptureToastHide(); ns:CaptureBatch() end, "accent")
				button:SetPoint("RIGHT", frame.ignore, "LEFT", -6, 0)
				button:SetFrameLevel(frame.ignore:GetFrameLevel() or 1)
				button:SetScript("OnEnter", function(b) ShowTip(b, L.CAPTURE_BATCH_TIP) end)
				button:SetScript("OnLeave", HideTip)
				button:Hide()
				frame.all = button
			end
			return frame
		end
	end
	local show = ns.CaptureToastShow
	if show then
		function ns:CaptureToastShow(...)
			local frame = show(self, ...)
			if frame and frame.all then
				if self:CaptureBatchOffered() then frame.all:Show() else frame.all:Hide() end
			end
			return frame
		end
	end
end

-- /qc filet tout (ou all) : tout capturer ; le reste comme avant
if ns.EXTRA_COMMANDS and ns.EXTRA_COMMANDS["filet"] then
	local base = ns.EXTRA_COMMANDS["filet"]
	ns.EXTRA_COMMANDS["filet"] = function(self, rest, ...)
		local sub = tostring(rest or ""):match("^%s*(%S*)")
		sub = (sub or ""):lower()
		if sub == "tout" or sub == "all" then
			self:CaptureBatch()
			return
		end
		return base(self, rest, ...)
	end
	ns.EXTRA_COMMANDS["net"] = ns.EXTRA_COMMANDS["filet"]
end

if ns.Mark then ns.Mark("CaptureBatch") end
