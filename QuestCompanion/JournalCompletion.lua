-- JournalCompletion.lua -- page Exploration du carnet (1.5.0 ; « Complétion » jusqu'en 1.5.0)
--
-- Une seule page pour finir les zones (remplace Zones et la fiche de Zone) :
--   * à gauche, toutes les zones par niveau : nom, « ici », pourcentage et
--     filet de progression (doré à 100 %) ; jamais visitées en retrait ;
--     clic = la zone ; la molette fait défiler cette liste ;
--   * à droite, la zone choisie : carte (grand %, niveaux, barre, les quatre
--     paliers et ce qu'ils donnent, coffre à ouvrir, suivi à l'écran), trois
--     cartes de part (Lieux, Métiers, Quêtes) qui choisissent la liste
--     du dessous, la liste de la part (à faire d'abord), et une ligne du
--     bestiaire qui renvoie à la Ménagerie.
-- Page externe du carnet : ns.JOURNAL_PANES.progress (JournalWindow.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	JRN_SEC_progress       = "Exploration",
	JRN_SUB_progress       = "Finis les zones : paliers, coffres et aides de capture.",
	JRN_PROG_LEVELS        = "niveaux %d-%d",
	JRN_PROG_MARK          = "%d %%",
	JRN_PROG_TREAT         = "friandise",
	JRN_PROG_GIFT          = "%s + %s",
	JRN_PROG_AID_DRAW      = "une aide de capture",
	JRN_PROG_CHEST         = "coffre (palier %d)",
	JRN_PROG_CHEST_READY   = "coffre à ouvrir !",
	JRN_PROG_CHEST_OPENED  = "coffre ouvert",
	JRN_PROG_CHEST_GOLDEN  = "zone dorée",
	JRN_PROG_MARK_TIP      = "Chaque palier se gagne une fois par zone, dès que deux activités y sont suivies.",
	JRN_PROG_NONE          = "—",
	JRN_PROG_HERE          = "ici",
	JRN_PROG_UNSEEN        = "Zone jamais visitée : tout se dévoilera à ta première visite.",
	JRN_PROG_TIP_explore   = "Les villages et lieux de la zone. Clic : leur liste.",
	JRN_PROG_TIP_craft     = "Les ressources de ta compétence qui poussent ici. Clic : leur liste.",
	JRN_PROG_TIP_quests    = "Les quêtes de la zone que ton personnage peut faire. Clic : leur liste.",
	JRN_PROG_NA            = "Rien à suivre ici pour toi.",
	JRN_PROG_BESTIARY      = "Bestiaire : %d/%d abattues · détail dans la Ménagerie",
	JRN_PROG_BESTIARY_NAMED = "Bestiaire : %d/%d abattues (nommés %d/%d) · détail dans la Ménagerie",
	JRN_PROG_BESTIARY_NONE = "Bestiaire : aucune créature connue ici pour l'instant.",
	JRN_PROG_MEN_OPEN      = "Ménagerie",
}
local EN = {
	JRN_SEC_progress       = "Exploration",
	JRN_SUB_progress       = "Complete zones: milestones, chests and capture aids.",
	JRN_PROG_LEVELS        = "levels %d-%d",
	JRN_PROG_MARK          = "%d%%",
	JRN_PROG_TREAT         = "treat",
	JRN_PROG_GIFT          = "%s + %s",
	JRN_PROG_AID_DRAW      = "a capture aid",
	JRN_PROG_CHEST         = "chest (tier %d)",
	JRN_PROG_CHEST_READY   = "chest to open!",
	JRN_PROG_CHEST_OPENED  = "chest opened",
	JRN_PROG_CHEST_GOLDEN  = "golden zone",
	JRN_PROG_MARK_TIP      = "Each milestone is earned once per zone, as soon as two activities are tracked there.",
	JRN_PROG_NONE          = "—",
	JRN_PROG_HERE          = "here",
	JRN_PROG_UNSEEN        = "Never visited: everything will show on your first visit.",
	JRN_PROG_TIP_explore   = "The zone's villages and places. Click: their list.",
	JRN_PROG_TIP_craft     = "The resources of your skill that grow here. Click: their list.",
	JRN_PROG_TIP_quests    = "The zone's quests your character can do. Click: their list.",
	JRN_PROG_NA            = "Nothing to track here for you.",
	JRN_PROG_BESTIARY      = "Bestiary: %d/%d defeated · details in the Menagerie",
	JRN_PROG_BESTIARY_NAMED = "Bestiary: %d/%d defeated (named %d/%d) · details in the Menagerie",
	JRN_PROG_BESTIARY_NONE = "Bestiary: no known creature here yet.",
	JRN_PROG_MEN_OPEN      = "Menagerie",
}
ns.RegisterStrings(FR, EN)
ns.JOURNAL_PROGRESS_STRINGS = { fr = FR, en = EN }

-- les trois parts montrées (le combat vit dans la Ménagerie)
local PARTS = { "explore", "craft", "quests" }
-- part de complétion -> carte, quand la part ne le dit pas elle-même
local PART_TAB = { villages = "explore", gathering = "craft", quests = "quests" }
local MARKS = { 25, 50, 75, 100 }

-- Mesures (depuis le haut gauche de la zone utile, comme ui.At)
local LIST_W, GAP = 190, 16
local ZROW_H, ZROW_STEP = 26, 28
local CARD_H, TILE_H, TILE_GAP = 140, 54, 8
local PART_H, PART_GAP = 50, 8
local ITEM_H, ITEM_STEP, DETAIL_W = 24, 26, 150
local BAR_X, BAR_Y, TILES_Y = 16, -62, -74
local NAME_X = 104

local function ZoneName(self, zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	if info and info.name and info.name ~= "" then return info.name end
	local stamp = self.JournalData and self:JournalData().stamps["zone:" .. tostring(zoneID)]
	return (stamp and stamp.name) or tostring(zoneID)
end

local function Paint(region, c) region:SetTextColor(c[1], c[2], c[3]) end
local function NoWrap(text) if text.SetWordWrap then text:SetWordWrap(false) end return text end

-- carte de chaque part de complétion (la sienne, sinon PART_TAB)
local function PartTabs()
	local tabs = {}
	for _, def in ipairs(ns.ZONE_PARTS or {}) do tabs[def.id] = def.tab or PART_TAB[def.id] end
	return tabs
end

-- Ce que donne un palier : friandise (Festin à 75) et l'aide de capture
-- (Capture.lua) ; à 100 : le coffre et son état
function ns:JournalMilestoneGift(zoneID, mark)
	if mark >= 100 then
		local chest = self.ChestData and self:ChestData()[zoneID]
		if chest and chest.golden then return L.JRN_PROG_CHEST_GOLDEN end
		if chest and chest.opened then return L.JRN_PROG_CHEST_OPENED end
		if chest then return L.JRN_PROG_CHEST_READY end
		return self:F("JRN_PROG_CHEST", self.ZoneTier and self:ZoneTier(zoneID) or 1)
	end
	local treat = mark >= 75 and (self.TreatLabel and self:TreatLabel("festin") or "Festin") or L.JRN_PROG_TREAT
	local drop = ns.CAPTURE_MILESTONE_DROPS and ns.CAPTURE_MILESTONE_DROPS[mark]
	if not drop then return treat end
	local aid = drop == "draw" and L.JRN_PROG_AID_DRAW or (self.CaptureAidLabel and self:CaptureAidLabel(drop)) or drop
	return self:F("JRN_PROG_GIFT", treat, aid)
end

-- Où en est une zone, carte par carte : { explore = { have, need }, … }
function ns:JournalProgressParts(zoneID)
	local out = {}
	for _, key in ipairs(PARTS) do out[key] = { have = 0, need = 0 } end
	local done = zoneID and self.ZoneCompletion and self:ZoneCompletion(zoneID)
	local tabs = PartTabs()
	for _, part in ipairs(done and done.parts or {}) do
		local slot = out[tabs[part.id] or ""]
		if slot then slot.have, slot.need = slot.have + part.have, slot.need + part.need end
	end
	return out, done
end

-- Tes métiers, nommés (1.5.1) : la carte Métiers dit ce qu'elle a repéré,
-- même quand rien ne se suit ici (artisanat, cuisine, pêche, secourisme)
function ns:JournalCraftLines()
	local text = self.PlayerProfessionsText and self:PlayerProfessionsText()
	if not text then return { L.GATHER_PROFS_NONE or "" } end
	return { self:F("GATHER_PROFS", text), L.GATHER_ONLY_GATHER }
end

-- Éléments d'une part : à faire d'abord, puis faits (ordre de la part gardé) ;
-- les quêtes proposées sur la carte, hors compte, à la suite sous leur titre
function ns:JournalProgressItems(zoneID, part)
	local todo, done, live, heads, locked = {}, {}, {}, {}, {}
	local inLive = false
	for _, row in ipairs(zoneID and self.JournalActivityRows and self:JournalActivityRows(zoneID, part) or {}) do
		if row.header then
			inLive = row.live == true
			if inLive then live[#live + 1] = row else heads[#heads + 1] = row.name end
		elseif inLive then
			live[#live + 1] = row
		elseif row.done then
			done[#done + 1] = row
		elseif row.locked then
			locked[#locked + 1] = row      -- pas encore à ta portée : tout en bas
		else
			todo[#todo + 1] = row
		end
	end
	for _, row in ipairs(done) do todo[#todo + 1] = row end
	for _, row in ipairs(locked) do todo[#todo + 1] = row end
	for _, row in ipairs(live) do todo[#todo + 1] = row end
	return todo, heads
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function Build(self, frame, content, ui)
	local At, Text, Tip, HideTip = ui.At, ui.Text, ui.Tip, ui.HideTip
	local TOP, INNER, PAD, PAGER_Y = ui.TOP, ui.INNER, ui.PAD, ui.PAGER_Y
	local RX = LIST_W + GAP
	local RW = INNER - RX
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.prog = pane

	-- colonne de gauche : les zones, une rangée chacune
	pane.zoneRows = math.floor((TOP - PAGER_Y + ZROW_STEP - ZROW_H - 6) / ZROW_STEP)
	pane.zones = {}
	for index = 1, pane.zoneRows do
		local row = Theme.CreateTile(pane, LIST_W, ZROW_H)
		At(row, content, 0, TOP - (index - 1) * ZROW_STEP)
		row.rowFill = index % 2 == 0 and Theme.ROW_ALT or Theme.ROW
		row:SetFill(row.rowFill)
		row.name = NoWrap(Text(row, Theme.F_BODY, Theme.LABEL, LIST_W - 60))
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -4)
		row.percent = Text(row, Theme.F_SMALL, Theme.PARCHMENT, 36)
		row.percent:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -5)
		row.percent:SetJustifyH("RIGHT")
		row.here = Text(row, Theme.F_SMALL, Theme.BLUE)
		row.here:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8 - 36 - 4, -5)
		row.here:SetJustifyH("RIGHT")
		row.here:SetText(L.JRN_PROG_HERE)
		row.hereW = math.ceil(Theme.TextWidth(row, row.here:GetText(), Theme.F_SMALL)) + 6
		row.bar = Theme.CreateBar(row, LIST_W - 18, 2)
		row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -20)
		row:SetScript("OnClick", function(r) if r.zoneID then ns:JournalProgressPick(r.zoneID) end end)
		row.onEnter = function(r)
			local zone = r.zone
			if not zone then return end
			local lines = {}
			if zone.lo < 99 then lines[1] = ns:F("JRN_PROG_LEVELS", zone.lo, zone.hi) end
			if not zone.seen then lines[#lines + 1] = L.JRN_PROG_UNSEEN end
			Tip(r, zone.name, lines)
		end
		row.onLeave = HideTip
		row:Hide()
		pane.zones[index] = row
	end
	pane.zonePager = Theme.CreatePager(pane, function(delta)
		frame.progOffset = (frame.progOffset or 0) - delta * pane.zoneRows
		ns:RefreshJournal()
	end)
	pane.zonePager:SetWidth(LIST_W)
	pane.zonePager:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + LIST_W, PAGER_Y)

	-- message quand aucune zone n'est connue
	pane.none = Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT, RW)
	At(pane.none, content, RX, TOP)
	if pane.none.SetWordWrap then pane.none:SetWordWrap(true) end

	-- carte de la zone : grand %, nom, niveaux, suivi, coffre, barre, paliers
	local card = Theme.CreateTile(pane, RW, CARD_H, { kind = "Frame" })
	At(card, content, RX, TOP)
	pane.card = card
	pane.percent = Text(card, Theme.F_DISPLAY, Theme.PARCHMENT, NAME_X - 20)
	pane.percent:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
	pane.watch = Theme.CreateToggle(card, 32, 15, "Button")
	pane.watch:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -18)
	pane.watch:SetScript("OnClick", function()
		if frame.progZone then ns:JournalSetWatched(frame.progZone, not ns:JournalIsWatched(frame.progZone)) end
	end)
	pane.watch:SetScript("OnEnter", function(owner) Tip(owner, L.JRN_WATCH, { L.JRN_WATCH_TIP }) end)
	pane.watch:SetScript("OnLeave", HideTip)
	pane.watchLabel = Text(card, Theme.F_BODY, Theme.LABEL)
	pane.watchLabel:SetPoint("RIGHT", pane.watch, "LEFT", -8, 0)
	pane.watchLabel:SetJustifyH("RIGHT")
	pane.watchLabel:SetText(L.JRN_WATCH)
	local watchW = 32 + 8 + math.ceil(Theme.TextWidth(card, L.JRN_WATCH, Theme.F_BODY))
	pane.name = NoWrap(Text(card, Theme.F_TITLE, Theme.PARCHMENT, RW - NAME_X - 16 - watchW - 12))
	pane.name:SetPoint("TOPLEFT", card, "TOPLEFT", NAME_X, -16)
	pane.openChest = Theme.CreateButton(card, "auto", 22, L.JRN_OPEN_CHEST, function()
		if frame.progZone then ns:OpenChest(frame.progZone) end
	end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -36)
	pane.levels = NoWrap(Text(card, Theme.F_SMALL, Theme.MUTED_LIGHT, RW - NAME_X - 16 - pane.openChest:GetWidth() - 12))
	pane.levels:SetPoint("TOPLEFT", card, "TOPLEFT", NAME_X, -40)
	local barW = RW - 2 * BAR_X
	pane.bar = Theme.CreateBar(card, barW, 6)
	pane.bar:SetPoint("TOPLEFT", card, "TOPLEFT", BAR_X, BAR_Y)
	-- moins de deux parts : pas de %, on dit pourquoi à la place des paliers
	pane.nopct = Text(card, Theme.F_BODY, Theme.MUTED_LIGHT, barW)
	pane.nopct:SetPoint("TOPLEFT", card, "TOPLEFT", BAR_X, BAR_Y + 4)
	if pane.nopct.SetWordWrap then pane.nopct:SetWordWrap(true) end
	pane.nopct:SetText(L.JRN_ZONE_NOPCT)
	pane.marks = {}
	local tileW = math.floor((barW - (#MARKS - 1) * TILE_GAP) / #MARKS)
	for index, mark in ipairs(MARKS) do
		local tile = Theme.CreateTile(card, tileW, TILE_H, { kind = "Frame" })
		tile:SetPoint("TOPLEFT", card, "TOPLEFT", BAR_X + (index - 1) * (tileW + TILE_GAP), TILES_Y)
		tile:SetFill(Theme.FIELD)
		tile.mark = mark
		tile.label = NoWrap(Text(tile, Theme.F_LABEL, Theme.MUTED, tileW - 20))
		tile.label:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -7)
		tile.label:SetText(ns:F("JRN_PROG_MARK", mark))
		tile.gift = Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, tileW - 20)
		tile.gift:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -24)
		if tile.gift.SetWordWrap then tile.gift:SetWordWrap(true) end
		if tile.gift.SetHeight then tile.gift:SetHeight(TILE_H - 24 - 4) end
		if tile.EnableMouse then tile:EnableMouse(true) end
		tile.onEnter = function(t) Tip(t, t.label:GetText(), { t.gift:GetText(), L.JRN_PROG_MARK_TIP }) end
		tile.onLeave = HideTip
		pane.marks[index] = tile
	end

	-- trois cartes de part : clic = la liste du dessous
	local partY = TOP - CARD_H - 10
	local partW = math.floor((RW - (#PARTS - 1) * PART_GAP) / #PARTS)
	pane.parts = {}
	for index, key in ipairs(PARTS) do
		local tile = Theme.CreateTile(pane, partW, PART_H)
		At(tile, content, RX + (index - 1) * (partW + PART_GAP), partY)
		tile.part = key
		tile.label = NoWrap(Text(tile, Theme.F_LABEL, Theme.LABEL, partW - 24 - 56))
		tile.label:SetPoint("TOPLEFT", tile, "TOPLEFT", 12, -9)
		tile.label:SetText(L["JRN_ACT_" .. key])
		tile.count = Text(tile, Theme.F_LABEL, Theme.PARCHMENT, 56)
		tile.count:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -12, -9)
		tile.count:SetJustifyH("RIGHT")
		tile.bar = Theme.CreateBar(tile, partW - 24, 4)
		tile.bar:SetPoint("TOPLEFT", tile, "TOPLEFT", 12, -32)
		tile:SetScript("OnClick", function(t) ns:JournalProgressPart(t.part) end)
		tile.onEnter = function(t)
			local lines = { L["JRN_PROG_TIP_" .. t.part] }
			if t.part == "quests" then
				local available = ns.ZoneQuestsAvailable and ns:ZoneQuestsAvailable()
				lines[2] = available and L.JRN_QUESTS_TIP or L.JRN_ACT_NO_QUESTS
			elseif t.part == "craft" then
				for _, line in ipairs(ns:JournalCraftLines()) do lines[#lines + 1] = line end
			end
			Tip(t, L["JRN_ACT_" .. t.part], lines)
		end
		tile.onLeave = HideTip
		pane.parts[key] = tile
		pane.parts[index] = tile
	end

	-- la liste de la part : en-tête (« Villages : 1/3 ») et pagination à droite
	local headY = partY - PART_H - 12
	pane.listPager = Theme.CreatePager(pane, function(delta)
		frame.progItemOffset = (frame.progItemOffset or 0) - delta * #pane.items
		ns:RefreshJournal()
	end)
	pane.listPager:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, headY)
	pane.head = NoWrap(Text(pane, Theme.F_LABEL, Theme.GOLD, RW - 200 - 8))
	At(pane.head, content, RX, headY - 4)
	local itemsTop = headY - Theme.PAGER_HEIGHT - 4
	local itemRows = math.floor((itemsTop - PAGER_Y - 12 + ITEM_STEP - ITEM_H) / ITEM_STEP)
	pane.items = {}
	for index = 1, itemRows do
		local line = Theme.CreateListRow(pane, RW, ITEM_H, { status = 9, detail = true })
		At(line, content, RX, itemsTop - (index - 1) * ITEM_STEP)
		line:SetIndex(index)
		line.rowAlt = line.alt
		line.detail:SetWidth(DETAIL_W)
		line.text:SetWidth(RW - line.textLeft - DETAIL_W - 12 - 8)
		line:Hide()
		pane.items[index] = line
	end
	-- zone où glisse la molette pour la liste (le reste fait défiler les zones)
	pane.itemArea = CreateFrame("Frame", nil, pane)
	At(pane.itemArea, content, RX, headY)
	pane.itemArea:SetSize(RW, headY - (itemsTop - (itemRows - 1) * ITEM_STEP - ITEM_H))
	pane.empty = Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT, RW)
	At(pane.empty, content, RX, itemsTop - 6)
	if pane.empty.SetWordWrap then pane.empty:SetWordWrap(true) end

	-- bestiaire : une ligne, le détail est dans la Ménagerie
	pane.toMen = Theme.CreateButton(pane, "auto", Theme.PAGER_HEIGHT, L.JRN_PROG_MEN_OPEN, function()
		if frame.progZone and ns.OpenMenagerieZone then ns:OpenMenagerieZone(frame.progZone) end
	end, "accent")
	pane.toMen:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, PAGER_Y)
	pane.bestiary = NoWrap(Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, RW - pane.toMen:GetWidth() - 12))
	At(pane.bestiary, content, RX, PAGER_Y - 5)
	pane:Hide()
end

-- ---------------------------------------------------------------------------
-- Choix (zone, part) et molette
-- ---------------------------------------------------------------------------
function ns:JournalProgressPick(zoneID)
	local frame = self.journalFrame
	if not frame then return end
	frame.zoneID, frame.zonePicked, frame.progItemOffset = tonumber(zoneID), true, 0
	-- cliquée dans la liste : déjà visible, la liste ne bouge pas
	frame.progFollowed = frame.zoneID
	self:RefreshJournal()
end

function ns:JournalProgressPart(part)
	local frame = self.journalFrame
	if not frame then return end
	frame.progPart, frame.progItemOffset = part, 0
	self:RefreshJournal()
end

local function Scroll(self, frame, delta)
	local pane = frame.prog
	delta = tonumber(delta) or 0
	local area = pane and pane.itemArea
	-- sur la liste de la part : une ligne ; ailleurs : trois zones
	if area and area.IsMouseOver and area:IsMouseOver() then
		frame.progItemOffset = (frame.progItemOffset or 0) - delta
	else
		frame.progOffset = (frame.progOffset or 0) - delta * 3
	end
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
local function RefreshZoneList(self, frame, pane, list, zoneID)
	local page = #pane.zones
	local maxOffset = math.max(0, #list - page)
	-- une zone choisie hors de la liste (ouverture, objectif) : on la montre
	if zoneID and frame.progFollowed ~= zoneID then
		frame.progFollowed = zoneID
		for index, zone in ipairs(list) do
			if zone.id == zoneID then
				local offset = frame.progOffset or 0
				if index <= offset or index > offset + page then frame.progOffset = index - math.floor(page / 2) end
			end
		end
	end
	frame.progOffset = math.max(0, math.min(frame.progOffset or 0, maxOffset))
	for index, row in ipairs(pane.zones) do
		local zone = list[index + frame.progOffset]
		row.zone, row.zoneID = zone, zone and zone.id
		if zone then
			local golden = zone.percent == 100
			row.name:SetText(zone.name)
			row.name:SetWidth(LIST_W - 10 - 8 - 36 - 4 - (zone.here and row.hereW or 0) - 4)
			Paint(row.name, zone.seen and Theme.LABEL or Theme.MUTED_LIGHT)
			if zone.here then row.here:Show() else row.here:Hide() end
			row.percent:SetText((zone.seen and zone.percent) and self:F("JRN_ZONE_PERCENT", zone.percent) or L.JRN_PROG_NONE)
			Paint(row.percent, golden and Theme.GOLD or (zone.seen and Theme.PARCHMENT or Theme.MUTED))
			if zone.seen and zone.percent then
				row.bar:SetValue(zone.percent / 100)
				local c = golden and Theme.GOLD or Theme.MUTED_LIGHT
				row.bar:SetColor(c[1], c[2], c[3], 1)
				row.bar:Show()
			else
				row.bar:Hide()
			end
			local selected = zone.id == zoneID
			row:SetSelected(selected)
			row:SetAccent(selected and Theme.GOLD or nil)
			row:SetFill(selected and Theme.ROW_ALT or row.rowFill)
			row:SetAlpha(zone.seen and 1 or 0.55)
			row:Show()
		else
			row:Hide()
		end
	end
	pane.zonePager:Update(frame.progOffset, page, #list, maxOffset)
end

local function ShowRight(pane, on)
	for _, region in ipairs({ pane.card, pane.head, pane.listPager, pane.empty, pane.bestiary, pane.toMen, pane.itemArea }) do
		if on then region:Show() else region:Hide() end
	end
	for _, tile in ipairs(pane.parts) do if on then tile:Show() else tile:Hide() end end
	if not on then for _, line in ipairs(pane.items) do line:Hide() end end
end

local function RefreshCard(self, frame, pane, zoneID, here, done)
	local counted = done and #done.parts >= 2
	local name = ZoneName(self, zoneID)
	pane.name:SetText(zoneID == here and self:F("JRN_ZONE_HERE", name) or name)
	local range = self.ZoneLevelRange and self:ZoneLevelRange(zoneID)
	pane.levels:SetText(range and self:F("JRN_PROG_LEVELS", range[1], range[2]) or "")
	pane.percent:SetText(counted and self:F("JRN_ZONE_PERCENT", done.percent) or L.JRN_PROG_NONE)
	Paint(pane.percent, (counted and done.percent >= 100) and Theme.GOLD or (counted and Theme.PARCHMENT or Theme.MUTED))
	if counted then
		pane.bar:SetValue(done.ratio)
		pane.bar:Show()
		pane.nopct:Hide()
	else
		pane.bar:Hide()
		pane.nopct:Show()
	end
	for _, tile in ipairs(pane.marks) do
		local reached = counted and done.percent >= tile.mark
		tile.reached = reached
		tile.gift:SetText(self:JournalMilestoneGift(zoneID, tile.mark))
		Paint(tile.label, reached and Theme.GOLD or Theme.MUTED)
		Paint(tile.gift, reached and Theme.LABEL or Theme.MUTED_LIGHT)
		tile:SetAccent(reached and Theme.GOLD or nil)
		if counted then tile:Show() else tile:Hide() end
	end
	local chest = self.ChestData and self:ChestData()[zoneID]
	local pending = chest and not chest.opened and not chest.golden
	if pending then pane.openChest:Show() else pane.openChest:Hide() end
	pane.card:SetAccent((pending or (chest and chest.golden)) and Theme.GOLD or nil)
	pane.watch:SetChecked(self.JournalIsWatched and self:JournalIsWatched(zoneID))
	pane.watch:Show()
end

local function RefreshParts(self, frame, pane, zoneID, parts)
	local quests = self.ZoneQuestsAvailable and self:ZoneQuestsAvailable()
	local selected = frame.progPart or "explore"
	for _, tile in ipairs(pane.parts) do
		local part = parts[tile.part]
		local applies = part.need > 0 and (tile.part ~= "quests" or quests)
		tile.count:SetText(part.need > 0 and string.format("%d/%d", part.have, part.need) or L.JRN_PROG_NONE)
		local full = part.need > 0 and part.have >= part.need
		Paint(tile.count, full and Theme.GOLD or (applies and Theme.PARCHMENT or Theme.MUTED))
		Paint(tile.label, applies and Theme.LABEL or Theme.MUTED)
		tile.bar:SetValue(part.need > 0 and part.have / part.need or 0)
		tile.dim = not applies
		tile:SetAlpha(applies and 1 or 0.5)
		local on = tile.part == selected
		tile:SetSelected(on)
		tile:SetAccent(on and Theme.GOLD or nil)
		tile:Show()
	end
	return selected, quests
end

local function RefreshItems(self, frame, pane, zoneID, part, quests, seen)
	local rows, heads = self:JournalProgressItems(zoneID, part)
	frame.progRows = rows
	pane.head:SetText(#heads > 0 and table.concat(heads, "  ·  ") or L["JRN_ACT_" .. part])
	local page = #pane.items
	local maxOffset = math.max(0, #rows - page)
	frame.progItemOffset = math.max(0, math.min(frame.progItemOffset or 0, maxOffset))
	for index, line in ipairs(pane.items) do
		local item = rows[index + frame.progItemOffset]
		line.item = item
		if not item then
			line:Hide()
		elseif item.header then
			line.status:Hide()
			line.text:SetText(item.name)
			Paint(line.text, Theme.GOLD)
			line.detail:SetText("")
			line.bg:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.08)
			line:Show()
		else
			line.status:Show()
			line.status:SetTexture(item.done and Theme.DIAMOND or Theme.DIAMOND_LINE)
			local c = item.done and Theme.GOLD or Theme.MUTED
			line.status:SetVertexColor(c[1], c[2], c[3], 1)
			line.text:SetText(tostring(item.name or ""))
			Paint(line.text, item.done and Theme.PARCHMENT or (item.locked and Theme.MUTED or Theme.TEXT))
			line.detail:SetText(Theme.T_GREY .. tostring(item.detail or "") .. "|r")
			line:SetAlt(line.rowAlt)
			line:Show()
		end
	end
	local empty = ""
	if #rows == 0 then
		if not seen then
			empty = L.JRN_PROG_UNSEEN
		elseif part == "quests" and not quests then
			empty = L.JRN_ACT_NO_QUESTS
		else
			empty = L["JRN_ACT_EMPTY_" .. part] or L.JRN_PROG_NA
			if part == "craft" then empty = table.concat({ empty, unpack(self:JournalCraftLines()) }, "\n") end
		end
	end
	pane.empty:SetText(empty)
	pane.listPager:Update(frame.progItemOffset, page, #rows, maxOffset)
end

local function RefreshBestiary(self, frame, pane, zoneID)
	local counts = self.BestiaryCounts and self:BestiaryCounts(zoneID)
	if not counts or counts.seen == 0 then
		pane.bestiary:SetText(L.JRN_PROG_BESTIARY_NONE)
	elseif counts.namedSeen > 0 then
		pane.bestiary:SetText(self:F("JRN_PROG_BESTIARY_NAMED", counts.killed, counts.seen, counts.namedKilled, counts.namedSeen))
	else
		pane.bestiary:SetText(self:F("JRN_PROG_BESTIARY", counts.killed, counts.seen))
	end
	if self.OpenMenagerieZone and frame.men then pane.toMen:Show() else pane.toMen:Hide() end
end

local function Refresh(self, frame, ui)
	local pane = frame.prog
	if not pane then return end
	local here = self.JournalZone and self:JournalZone()
	local list = self:JournalAllZones("all", "lvl")
	-- par défaut la zone où tu es (sinon la première visitée) ; un choix tient
	-- jusqu'à la fermeture du carnet (ToggleJournal oublie zonePicked)
	if not frame.zonePicked or not frame.zoneID then
		frame.zoneID = here
		if not frame.zoneID then
			for _, zone in ipairs(list) do if zone.seen then frame.zoneID = zone.id; break end end
		end
	end
	local zoneID = frame.zoneID
	if frame.progZone ~= zoneID then frame.progItemOffset = 0 end
	frame.progZone = zoneID
	RefreshZoneList(self, frame, pane, list, zoneID)
	if not zoneID then
		ShowRight(pane, false)
		pane.none:SetText(L.JRN_ZONE_NONE)
		pane.none:Show()
		return
	end
	pane.none:Hide()
	ShowRight(pane, true)
	local seen = zoneID == here
	for _, zone in ipairs(list) do if zone.id == zoneID and zone.seen then seen = true end end
	local parts, done = self:JournalProgressParts(zoneID)
	RefreshCard(self, frame, pane, zoneID, here, done)
	local part, quests = RefreshParts(self, frame, pane, zoneID, parts)
	RefreshItems(self, frame, pane, zoneID, part, quests, seen)
	RefreshBestiary(self, frame, pane, zoneID)
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.progress = {
	field = "prog", title = "JRN_SEC_progress", subtitle = "JRN_SUB_progress",
	build = Build, refresh = Refresh, scroll = Scroll,
}
ns.JOURNAL_PROGRESS_LAYOUT = { listW = LIST_W, gap = GAP, cardH = CARD_H, partH = PART_H, itemStep = ITEM_STEP }
