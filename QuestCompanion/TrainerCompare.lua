-- TrainerCompare.lua -- 3.7.0 : comparer ses hauts faits avec ceux d'un
-- autre dresseur (docs/qc-gameplay-viral, chantier D, point 7).
--
-- La fiche reçue porte un bit par haut fait obtenu (champ fb, ns:FeatBits) :
-- on sait ce que l'autre a, jamais sa progression. Fenêtre « Comparer les
-- hauts faits », ouverte depuis la fiche d'un autre dresseur :
--   * par famille, une section « <FAMILLE> · <n> HAUTS FAITS COMPARÉS » (n :
--     lignes comparées de la famille), deux colonnes « TOI » et son nom ;
--   * une ligne par haut fait que l'un a et l'autre non, d'abord ceux qui te
--     manquent ; ta colonne : la case cochée ou ta progression « cur / max » ;
--     la sienne : la case cochée ou un tiret ;
--   * lignes comparées : ni en attente, ni tour de force ; un secret que tu
--     n'as pas découvert se lit « Un secret du compagnon », sans condition ni
--     progression (rien ne fuit) ;
--   * molette au-delà de la hauteur ; pied : les comptes (tournure neutre,
--     on ne connaît pas le genre de l'autre), « Voir sa fiche », « Fermer » ;
--     Échap ferme, le combat ferme (et empêche d'ouvrir).
-- Honorifique : rien ne se gagne, hormis le compteur « compare » (Tally.lua,
-- haut fait soc_compare) posé à chaque ouverture si la fonction existe.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	TRAINER_CMP_TITLE    = "Comparer les hauts faits",
	TRAINER_CMP_SUB      = "Toi et %s · fiche reçue le %s",
	TRAINER_CMP_SUB_NOW  = "Toi et %s",
	TRAINER_CMP_SECTION  = "%s · %d hauts faits comparés",
	TRAINER_CMP_ME       = "Toi",
	TRAINER_CMP_FOOT     = "Toi %d · %s %d · %d chez %s seulement · %d chez toi seulement",
	TRAINER_CMP_SAME     = "Aucune différence : vous avez obtenu les mêmes hauts faits.",
	TRAINER_CMP_CARD     = "Voir sa fiche",
}
local EN = {
	TRAINER_CMP_TITLE    = "Compare achievements",
	TRAINER_CMP_SUB      = "You and %s · card received on %s",
	TRAINER_CMP_SUB_NOW  = "You and %s",
	TRAINER_CMP_SECTION  = "%s · %d achievements compared",
	TRAINER_CMP_ME       = "You",
	TRAINER_CMP_FOOT     = "You %d · %s %d · %d only with %s · %d only with you",
	TRAINER_CMP_SAME     = "No difference: you both earned the same achievements.",
	TRAINER_CMP_CARD     = "View their card",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAINER_CMP_STRINGS = { fr = FR, en = EN } end

-- Mise en page (px) : fenêtre, marge, liste de SLOTS emplacements de STEP px,
-- colonnes de COL px au bord droit de la liste, écart GAP
ns.TRAINER_CMP = { width = 620, height = 400, footer = 52, pad = 30, listY = -80, slots = 7, step = 36, rowH = 34,
	col = 74, gap = 8, check = 12 }
local K = ns.TRAINER_CMP

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function InCombat()
	if Call(G("InCombatLockdown")) == true then return true end
	return ns.Plain and ns.Plain(Call(G("UnitAffectingCombat"), "player")) == true or false
end

-- ---------------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------------
-- Une ligne se compare : ni en attente, ni tour de force
local function Comparable(def)
	return type(def) == "table" and not def.pending and def.cat ~= (ns.FEAT_FOS or "fos") and tonumber(def.n) ~= nil
end

-- Un secret que je n'ai pas : ni nom, ni condition, ni progression
local function Hidden(self, def) return def.hidden and not self:FeatGot(def) end

-- card : fiche reçue (avec featBits). Rend { families = { { id, label, compared,
-- rows = { { def, mine, theirs } } } }, mine, theirs, onlyTheirs, onlyMine },
-- ou nil sans bits (fiche d'avant la 3.7)
function ns:TrainerCompareData(card)
	if type(card) ~= "table" or type(card.featBits) ~= "string" or not (self.FeatDefs and self.FeatBitsDecode) then return nil end
	local theirSet = self:FeatBitsDecode(card.featBits)
	local byFamily, data = {}, { families = {}, mine = 0, theirs = 0, onlyTheirs = 0, onlyMine = 0 }
	for _, fam in ipairs(ns.FEAT_FAMILIES or {}) do
		byFamily[fam] = { id = fam, label = L["FEATF_" .. fam] or fam, compared = 0, rows = {} }
		data.families[#data.families + 1] = byFamily[fam]
	end
	for _, def in ipairs(self:FeatDefs()) do
		local cat = Comparable(def) and self.FeatCategory and self:FeatCategory(def.cat)
		local family = cat and byFamily[cat.family]
		if family then
			local mine = self:FeatGot(def) and true or false
			local theirs = theirSet[tonumber(def.n)] == true
			family.compared = family.compared + 1
			if mine then data.mine = data.mine + 1 end
			if theirs then data.theirs = data.theirs + 1 end
			if mine ~= theirs then
				family.rows[#family.rows + 1] = { def = def, mine = mine, theirs = theirs }
				if theirs then data.onlyTheirs = data.onlyTheirs + 1 else data.onlyMine = data.onlyMine + 1 end
			end
		end
	end
	for _, family in ipairs(data.families) do
		-- d'abord ce qui me manque, puis ce qu'il me reste en propre ; ordre du catalogue
		table.sort(family.rows, function(a, b)
			if a.theirs ~= b.theirs then return a.theirs end
			return tonumber(a.def.n) < tonumber(b.def.n)
		end)
	end
	return data
end

-- La liste à l'écran : en-têtes de famille et lignes, dans l'ordre (les
-- familles sans différence sont tues)
function ns:TrainerCompareItems(data)
	local items = {}
	for _, family in ipairs(data and data.families or {}) do
		if #family.rows > 0 then
			items[#items + 1] = { header = true, family = family }
			for _, row in ipairs(family.rows) do items[#items + 1] = row end
		end
	end
	return items
end

-- Texte d'une ligne : nom, condition (vide pour un secret non découvert)
function ns:TrainerCompareRowText(def)
	if Hidden(self, def) then return L.FEAT_SECRET_NAME or self:FeatName(def), "" end
	local ok, desc = pcall(self.FeatDescription, self, def)
	return self:FeatName(def), ok and type(desc) == "string" and desc or ""
end

-- Ma colonne : "check", ou le texte de ma progression (« 3 / 25 ») ; un secret
-- que je n'ai pas : un tiret
function ns:TrainerCompareMine(def)
	if self:FeatGot(def) then return "check" end
	if Hidden(self, def) then return "—" end
	local cur, max = self:FeatProgress(def)
	return string.format("%d / %d", math.floor(tonumber(cur) or 0), math.floor(tonumber(max) or 1))
end

-- ---------------------------------------------------------------------------
-- Fenêtre
-- ---------------------------------------------------------------------------
local function NewCheck(parent)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(K.check, K.check)
	box.bg = Theme.Solid(box, "BACKGROUND", Theme.GREEN, 0.14)
	box.bg:SetAllPoints()
	box.border = Theme.Border(box, Theme.GREEN, 1)
	box.mark = box:CreateTexture(nil, "ARTWORK")
	box.mark:SetTexture(Theme.CHECK_FILE)
	box.mark:SetSize(K.check + 4, K.check + 4)
	box.mark:SetPoint("CENTER", box, "CENTER", 0, 0)
	box.mark:SetVertexColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3], 1)
	return box
end

-- Une cellule de colonne : case cochée (texture) ou texte
local function NewCell(parent, x)
	local cell = { }
	cell.check = NewCheck(parent)
	cell.check:SetPoint("CENTER", parent, "LEFT", x, 0)
	cell.text = Theme.Text(parent, Theme.F_SMALL, Theme.MUTED_LIGHT)
	cell.text:SetPoint("CENTER", parent, "LEFT", x, 0)
	function cell:Set(value)
		if value == "check" then
			self.check:Show(); self.text:SetText("")
		else
			self.check:Hide(); self.text:SetText(value or "")
		end
		self.value = value
	end
	return cell
end

local function BuildSlot(parent, index, width)
	local slot = CreateFrame("Frame", nil, parent)
	slot:SetSize(width, K.rowH)
	slot:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * K.step)
	local xMine = width - K.col - K.gap - K.col / 2
	local xTheirs = width - K.col / 2
	-- en-tête de famille : section, puis « TOI » et son nom
	slot.section = Theme.CreateSection(slot, "")
	slot.section:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
	slot.section:SetWidth(width - 2 * K.col - 2 * K.gap)
	slot.meTag = Theme.CreateTag(slot, "", Theme.BLUE)
	slot.themTag = Theme.CreateTag(slot, "", Theme.BLUE)
	-- ligne : tuile, nom, condition, deux cellules
	slot.tile = Theme.CreateTile(slot, width, K.rowH, { kind = "Frame", accent = false })
	slot.tile:SetAllPoints(slot)
	slot.name = Theme.Text(slot.tile, Theme.F_LABEL, Theme.LABEL)
	slot.name:SetPoint("LEFT", slot.tile, "LEFT", 10, 0)
	slot.name:SetJustifyH("LEFT")
	if slot.name.SetWordWrap then slot.name:SetWordWrap(false) end
	slot.desc = Theme.Text(slot.tile, Theme.F_SMALL, Theme.MUTED_LIGHT)
	slot.desc:SetPoint("LEFT", slot.name, "RIGHT", 4, 0)
	slot.desc:SetJustifyH("LEFT")
	if slot.desc.SetWordWrap then slot.desc:SetWordWrap(false) end
	slot.mine = NewCell(slot.tile, xMine)
	slot.theirs = NewCell(slot.tile, xTheirs)
	slot.xMine, slot.xTheirs, slot.width = xMine, xTheirs, width
	return slot
end

local function PaintSlot(self, frame, slot, item, alt)
	if not item then
		slot:Hide()
		return
	end
	slot:Show()
	slot.item = item
	if item.header then
		slot.tile:Hide()
		slot.section:Show()
		slot.section:SetText(self:F("TRAINER_CMP_SECTION", item.family.label, item.family.compared))
		for _, pair in ipairs({ { slot.meTag, L.TRAINER_CMP_ME, slot.xMine }, { slot.themTag, frame.otherName or "?", slot.xTheirs } }) do
			local tag = pair[1]
			tag:SetTag(pair[2], Theme.BLUE)
			tag:SetWidth(K.col)
			tag:ClearAllPoints()
			tag:SetPoint("CENTER", slot, "TOPLEFT", pair[3], -10)
		end
		return
	end
	slot.section:Hide(); slot.meTag:Hide(); slot.themTag:Hide()
	slot.tile:Show()
	slot.tile:SetFill(alt and Theme.ROW_ALT or Theme.ROW)
	local name, desc = self:TrainerCompareRowText(item.def)
	slot.name:SetText(name)
	slot.desc:SetText(desc ~= "" and ("· " .. desc) or "")
	-- la condition s'arrête avant ma colonne
	local ok, nameW = pcall(slot.name.GetStringWidth, slot.name)
	local room = slot.xMine - K.col / 2 - K.gap - 10 - 4 - (ok and tonumber(nameW) or 0)
	slot.desc:SetWidth(math.max(0, math.floor(room)))
	slot.mine:Set(self:TrainerCompareMine(item.def))
	slot.theirs:Set(item.theirs and "check" or "—")
end

function ns:TrainerComparePaint()
	local frame = self.trainerCompareFrame
	if not frame then return end
	local items = frame.items or {}
	local maxOffset = math.max(0, #items - K.slots)
	frame.offset = math.max(0, math.min(frame.offset or 0, maxOffset))
	local rowIndex = 0
	for index = 1, frame.offset do if items[index] and not items[index].header then rowIndex = rowIndex + 1 end end
	for index, slot in ipairs(frame.slots) do
		local item = items[frame.offset + index]
		if item and not item.header then rowIndex = rowIndex + 1 end
		PaintSlot(self, frame, slot, item, rowIndex % 2 == 0)
	end
	frame.same:SetText(#items == 0 and L.TRAINER_CMP_SAME or "")
	frame.maxOffset = maxOffset
end

-- delta : 1 vers le bas (molette vers soi), -1 vers le haut
function ns:TrainerCompareScroll(delta)
	local frame = self.trainerCompareFrame
	if not (frame and frame:IsShown()) then return false end
	local before = frame.offset or 0
	frame.offset = before + (tonumber(delta) or 0)
	self:TrainerComparePaint()
	return frame.offset ~= before
end

function ns:EnsureTrainerCompareWindow()
	if self.trainerCompareFrame then return self.trainerCompareFrame end
	if not (Theme and Theme.CreateWindow) then return nil end
	local W, H = K.width, K.height
	local frame = Theme.CreateWindow(UIParent, W, H, { name = "QuestCompanionTrainerCompare", footer = K.footer,
		strata = "FULLSCREEN_DIALOG" })
	if not frame then return nil end
	frame.chrome = "trainerCompare"
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	local content = frame.content
	frame.header = Theme.CreatePageHeader(content, W - 2, { compact = true, logo = false, pad = K.pad })
	frame.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	frame.header:SetTitle(L.TRAINER_CMP_TITLE)
	local listW = W - 2 - 2 * K.pad
	local list = CreateFrame("Frame", nil, content)
	list:SetSize(listW, K.slots * K.step)
	list:SetPoint("TOPLEFT", content, "TOPLEFT", K.pad, K.listY)
	if list.EnableMouseWheel then list:EnableMouseWheel(true) end
	list:SetScript("OnMouseWheel", function(_, delta) ns:TrainerCompareScroll((tonumber(delta) or 0) > 0 and -1 or 1) end)
	frame.list = list
	frame.slots = {}
	for index = 1, K.slots do frame.slots[index] = BuildSlot(list, index, listW) end
	frame.same = Theme.Text(list, Theme.F_BODY, Theme.MUTED_LIGHT)
	frame.same:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -8)
	frame.same:SetWidth(listW)
	frame.same:SetJustifyH("LEFT")
	frame.summary = Theme.Text(content, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.summary:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -4)
	frame.summary:SetWidth(listW)
	frame.summary:SetJustifyH("LEFT")
	local foot = frame.footer
	frame.closeButton = Theme.CreateButton(foot, "auto", "md", L.OPT_CLOSE, function() frame:Hide() end, "accent")
	frame.closeButton:SetPoint("RIGHT", foot, "RIGHT", -K.pad, 0)
	frame.cardButton = Theme.CreateButton(foot, "auto", "md", L.TRAINER_CMP_CARD, function()
		local who = frame.viewing
		frame:Hide()
		if who and ns.TrainerOpen then ns:TrainerOpen(who) end
	end)
	frame.cardButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -10, 0)
	-- le combat ferme la fenêtre
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", function(f, event)
		if event == "PLAYER_REGEN_DISABLED" and f:IsShown() then f:Hide() end
	end)
	frame:Hide()
	self.trainerCompareFrame = frame
	return frame
end

-- Ouvre la comparaison avec la fiche reçue de `name` ; nil en combat, sans
-- fiche, ou pour une fiche sans bits (avant la 3.7)
function ns:TrainerCompareOpen(name)
	if InCombat() or not name or not self.TrainerCard then return nil end
	local card, age = self:TrainerCard(name)
	local data = self:TrainerCompareData(card)
	if not data then return nil end
	local frame = self:EnsureTrainerCompareWindow()
	if not frame then return nil end
	frame.viewing, frame.card, frame.data = name, card, data
	local short = self.TrainerShortName and self:TrainerShortName(card.sender or name) or tostring(name)
	frame.otherName = short
	local heading = self.TrainerCardHeading and select(1, self:TrainerCardHeading(card, short)) or short
	local now = tonumber(Call(G("time"))) or 0
	local when = age and ns.TrainerFormatDate and ns.TrainerFormatDate(now - age) or nil
	frame.header:SetSubtitle(when and self:F("TRAINER_CMP_SUB", heading, when) or self:F("TRAINER_CMP_SUB_NOW", heading))
	frame.items = self:TrainerCompareItems(data)
	frame.offset = 0
	frame.summary:SetText(self:F("TRAINER_CMP_FOOT", data.mine, short, data.theirs, data.onlyTheirs, short, data.onlyMine))
	frame:Show()
	self:TrainerComparePaint()
	-- honorifique : seul le compteur bouge (haut fait soc_compare)
	if self.TallyAdd then pcall(self.TallyAdd, self, "compare") end
	return frame
end

if ns.Mark then ns.Mark("TrainerCompare") end
