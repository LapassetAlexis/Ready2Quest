-- SpellRanks.lua -- module QoL « Rangs de sorts » (Ready2Quest 1.27.0)
--
-- Un sort de tes barres d'action a-t-il un rang supérieur dans ton livre de
-- sorts ? (Éclair sacré Rang 3 sur la barre alors que tu connais le Rang 5.)
--   * contrôle : à la connexion, après un sort appris (maître de classe), et
--     quand une barre change ; jamais en combat ;
--   * annonce : l'icône de Ready2Quest (clic : la liste), une ligne dans le
--     chat, et une ligne du check avant le départ ;
--   * la liste : par sort, son rang et le meilleur connu, sa barre et sa case,
--     [Mettre à jour] (même case, meilleur rang) et [Ignorer] ;
--     [Tout mettre à jour] en bas ;
--   * sur les barres : un fin liseré rouge autour de la case concernée
--     (barres de Blizzard, Bartender4, Dominos), réglable ;
--   * ignorer, c'est ignorer une CASE pour ce sort : un Rang 1 gardé exprès
--     (soin bon marché) n'empêche pas d'être prévenu pour les autres cases ;
--     la liste des cases ignorées s'oublie dans les réglages.
-- Remplacer un sort : PickupSpell puis PlaceAction, hors combat seulement, et
-- toujours sur un clic.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.SPELLRANKS_SLOTS = 120       -- cases des barres (pages et barres de posture comprises)
ns.SPELLRANKS_ROWS = 8
local WIDTH = 520
local ROW_CARD, ROW_H = 36, 38       -- carte d'un sort, pas d'une ligne à l'autre
local GAP = 14
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local FR = {
	OPT_PAGE_SPELLRANKS     = "Rangs de sorts",
	OPT_PAGE_SPELLRANKS_SUB = "Un sort de tes barres a un meilleur rang dans ton livre : tu es prévenu.",
	OPT_SPELLRANKS_ENABLED  = "Activer le module",
	OPT_SPELLRANKS_FORGET   = "Oublier les cases ignorées",
	OPT_SPELLRANKS_BORDER   = "Liseré rouge autour des sorts à mettre à jour",
	SR_TITLE                = "Rangs de sorts",
	SR_SUB                  = "Les sorts de tes barres qui ont un meilleur rang.",
	SR_LINE                 = "%s : du rang %d au rang %d",
	SR_WHERE                = "barre %d, case %d",
	SR_BTN_UPDATE           = "Mettre à jour",
	SR_BTN_IGNORE           = "Ignorer",
	SR_BTN_ALL              = "Tout mettre à jour",
	SR_NONE                 = "Tous les sorts de tes barres sont à leur meilleur rang.",
	SR_COMBAT               = "En combat : la mise à jour attendra la fin du combat.",
	SR_MORE                 = "et %d autre(s)",
	SR_NOTICE               = "Sorts à mettre à jour : %d",
	SR_CHAT                 = "%d sort(s) de tes barres ont un meilleur rang dans ton livre. Clique sur l'icône, ou /r2q sorts.",
	SR_UPDATED              = "%s : rang %d sur la barre %d, case %d.",
	SR_IGNORED              = "%s (rang %d) gardé sur la barre %d, case %d.",
	SR_FORGOT               = "Cases ignorées oubliées : %d.",
	SR_PREVIEW_OLD          = "Rang 3, le 5 est appris",
	SR_PREVIEW_OK           = "Meilleur rang",
	SR_PREVIEW_ON           = "Sur tes barres, un liseré rouge entoure le sort à mettre à jour.",
	SR_PREVIEW_OFF          = "Liseré coupé : l'icône et le chat te préviennent quand même.",
	-- 1.31.0 : un nom et non un état (« à jour » contredisait l'échec)
	CHK_SPELLRANKS          = "Rangs de sorts",
	CHK_SPELLRANKS_GOOD     = "tous au meilleur rang",
	CHK_SPELLRANKS_DETAIL   = "%d sort(s) à un rang inférieur sur tes barres",
	ADV_SPELLRANKS          = "Mets à jour les sorts de tes barres (/r2q sorts).",
	HELP_SPELLRANKS         = "/r2q sorts — les sorts de tes barres qui ont un meilleur rang",
}
local EN = {
	OPT_PAGE_SPELLRANKS     = "Spell ranks",
	OPT_PAGE_SPELLRANKS_SUB = "A spell on your bars has a higher rank in your spellbook: you get told.",
	OPT_SPELLRANKS_ENABLED  = "Enable the module",
	OPT_SPELLRANKS_FORGET   = "Forget ignored slots",
	OPT_SPELLRANKS_BORDER   = "Red outline around spells to update",
	SR_TITLE                = "Spell ranks",
	SR_SUB                  = "Spells on your bars that have a higher rank.",
	SR_LINE                 = "%s: rank %d to rank %d",
	SR_WHERE                = "bar %d, slot %d",
	SR_BTN_UPDATE           = "Update",
	SR_BTN_IGNORE           = "Ignore",
	SR_BTN_ALL              = "Update all",
	SR_NONE                 = "Every spell on your bars is at its best rank.",
	SR_COMBAT               = "In combat: the update will wait until combat ends.",
	SR_MORE                 = "and %d more",
	SR_NOTICE               = "Spells to update: %d",
	SR_CHAT                 = "%d spell(s) on your bars have a higher rank in your spellbook. Click the icon, or /r2q sorts.",
	SR_UPDATED              = "%s: rank %d on bar %d, slot %d.",
	SR_IGNORED              = "%s (rank %d) kept on bar %d, slot %d.",
	SR_FORGOT               = "Ignored slots forgotten: %d.",
	SR_PREVIEW_OLD          = "Rank 3, rank 5 is known",
	SR_PREVIEW_OK           = "Best rank",
	SR_PREVIEW_ON           = "On your bars, a red outline surrounds the spell to update.",
	SR_PREVIEW_OFF          = "Outline off: the icon and the chat still tell you.",
	CHK_SPELLRANKS          = "Spell ranks",
	CHK_SPELLRANKS_GOOD     = "all at best rank",
	CHK_SPELLRANKS_DETAIL   = "%d spell(s) at a lower rank on your bars",
	ADV_SPELLRANKS          = "Update the spells on your bars (/r2q sorts).",
	HELP_SPELLRANKS         = "/r2q sorts — the spells on your bars that have a higher rank",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SPELLRANKS_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ spellranksEnabled = true, spellranksBorder = true })

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "spellranks", title = "OPT_PAGE_SPELLRANKS", parent = "qol", group = "OPT_GROUP_QOL",
		-- aperçu : deux cases de barre, le liseré rouge sur celle à mettre à jour
		preview = function(self, container) return self:SpellRanksPreview(container) end,
		rows = {
			{ key = "spellranksEnabled", label = "OPT_SPELLRANKS_ENABLED", kind = "bool" },
			{ key = "spellranksBorder", label = "OPT_SPELLRANKS_BORDER", kind = "bool" },
			{ key = "spellranksForget", label = "OPT_SPELLRANKS_FORGET", kind = "action", button = "OPT_BTN_FORGET" },
		},
	})
end
if type(ns.OPTION_ACTIONS) == "table" then
	ns.OPTION_ACTIONS.spellranksForget = function(self) self:SpellRanksForget() end
end
if ns.RegisterModule then
	ns.RegisterModule({ id = "spellranks", key = "spellranksEnabled", label = "OPT_PAGE_SPELLRANKS", aliases = { "sorts", "rangs" } })
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_MISC" and type(section[2]) == "table" then table.insert(section[2], "HELP_SPELLRANKS") end
	end
end
if type(ns.NOTICE_ICONS) == "table" then ns.NOTICE_ICONS.spells = BOOK_ICON end

local function Global(name)
	local value = rawget(_G, name)
	if type(value) == "function" then return value end
	return nil
end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end
local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.spellranksEnabled ~= false
end
local function InCombat()
	return Call(Global("InCombatLockdown")) == true
end
-- 1.32.2 (fiche 25) : les deux échéances (vérification, liserés) sont posées
-- sur l'horloge de l'addon (ns.Soon) au lieu d'un OnUpdate permanent
local ArmDue
-- Liserés à revoir dans `delay` secondes (la plus proche échéance l'emporte)
local function MarkSoon(delay)
	local at = ns.Now() + delay
	local due = ns.spellRanksMarkDueAt
	if not due or due > at then ns.spellRanksMarkDueAt = at end
	ArmDue()
end

local function C(name)
	local api = rawget(_G, "C_Spell")
	if type(api) == "table" and type(api[name]) == "function" then return api[name] end
	return nil
end

-- Nom et rang d'un sort (« Rang 3 » / « Rank 3 » -> 3 ; sans rang : nil)
function ns:SpellRankOf(spellID)
	local name
	local fn = C("GetSpellName")
	if fn then name = Call(fn, spellID) end
	if not name then name = Call(Global("GetSpellInfo"), spellID) end
	local sub = Call(C("GetSpellSubtext") or Global("GetSpellSubtext"), spellID)
	local rank = tonumber(tostring(sub or ""):match("(%d+)"))
	return name, rank
end

-- Le meilleur rang connu de chaque sort, par son nom : { name = { id, rank } }
local function Keep(best, name, id, rank)
	if not (name and id and rank) then return end
	local current = best[name]
	if not current or rank > current.rank then best[name] = { id = id, rank = rank } end
end
function ns:SpellRankBook()
	local best = {}
	local book = rawget(_G, "C_SpellBook")
	local bank = rawget(_G, "Enum") and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
	if type(book) == "table" and type(book.GetNumSpellBookSkillLines) == "function" and bank ~= nil then
		for line = 1, tonumber((Call(book.GetNumSpellBookSkillLines))) or 0 do
			local info = Call(book.GetSpellBookSkillLineInfo, line)
			if type(info) == "table" and not info.offSpecID then
				local first = tonumber(info.itemIndexOffset) or 0
				for index = first + 1, first + (tonumber(info.numSpellBookItems) or 0) do
					local item = Call(book.GetSpellBookItemInfo, index, bank)
					if type(item) == "table" and item.spellID and not item.isPassive then
						local name, rank = self:SpellRankOf(item.spellID)
						Keep(best, item.name or name, item.spellID, rank)
					end
				end
			end
		end
		return best
	end
	-- ancien livre : onglets, puis GetSpellBookItemInfo(index, "spell")
	for tab = 1, tonumber((Call(Global("GetNumSpellTabs")))) or 0 do
		local _, _, offset, count = Call(Global("GetSpellTabInfo"), tab)
		for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
			local kind, spellID = Call(Global("GetSpellBookItemInfo"), index, "spell")
			if kind == "SPELL" and spellID then
				local name, rank = self:SpellRankOf(spellID)
				Keep(best, name, spellID, rank)
			end
		end
	end
	return best
end

-- Les cases dont le sort a un meilleur rang, sans les cases ignorées
-- (`all` : celles-ci aussi, marquées `ignored`)
function ns:SpellRankScan(all)
	local list = {}
	local best = self:SpellRankBook()
	local ignore = self:DB().spellranksIgnore or {}
	for slot = 1, ns.SPELLRANKS_SLOTS do
		local kind, id = Call(Global("GetActionInfo"), slot)
		if kind == "spell" and id then
			local name, rank = self:SpellRankOf(id)
			local top = name and best[name]
			if rank and top and top.rank > rank and top.id ~= id then
				local ignored = ignore[slot .. ":" .. id] == true
				if all or not ignored then
					list[#list + 1] = { slot = slot, id = id, name = name, rank = rank, bestID = top.id,
						bestRank = top.rank, ignored = ignored, bar = math.floor((slot - 1) / 12) + 1, case = (slot - 1) % 12 + 1 }
				end
			end
		end
	end
	return list
end

-- Remplace le sort de la case par son meilleur rang (hors combat)
function ns:SpellRankUpdate(entry)
	if not entry then return false end
	if InCombat() then self:Print(L.SR_COMBAT); return false end
	local kind, id = Call(Global("GetActionInfo"), entry.slot)
	if kind ~= "spell" or id ~= entry.id then return false end
	local pickup = C("PickupSpell") or Global("PickupSpell")
	if not pickup then return false end
	Call(pickup, entry.bestID)
	Call(Global("PlaceAction"), entry.slot)
	Call(Global("ClearCursor"))
	self:Print(self:F("SR_UPDATED", entry.name, entry.bestRank, entry.bar, entry.case))
	self:SpellRanksRefresh()
	return true
end

function ns:SpellRankUpdateAll()
	if InCombat() then self:Print(L.SR_COMBAT); return 0 end
	local done = 0
	for _, entry in ipairs(self:SpellRankScan()) do
		if self:SpellRankUpdate(entry) then done = done + 1 end
	end
	return done
end

function ns:SpellRankIgnore(entry)
	if not entry then return false end
	local db = self:DB()
	db.spellranksIgnore = type(db.spellranksIgnore) == "table" and db.spellranksIgnore or {}
	db.spellranksIgnore[entry.slot .. ":" .. entry.id] = true
	self:Print(self:F("SR_IGNORED", entry.name, entry.rank, entry.bar, entry.case))
	self:SpellRanksRefresh()
	return true
end

function ns:SpellRanksForget()
	local db = self:DB()
	local count = 0
	for _ in pairs(type(db.spellranksIgnore) == "table" and db.spellranksIgnore or {}) do count = count + 1 end
	db.spellranksIgnore = {}
	self:Print(self:F("SR_FORGOT", count))
	self:SpellRanksRefresh()
	return count
end

-- ---------------------------------------------------------------------------
-- Annonce : l'icône et une ligne de chat, quand il y a du nouveau
-- ---------------------------------------------------------------------------
function ns:SpellRanksCheck()
	if not ModuleOn() then return 0 end
	if InCombat() then self.spellRanksPending = true; return nil end
	self.spellRanksPending = nil
	local list = self:SpellRankScan()
	local count = #list
	local previous = self.spellRanksAnnounced or 0
	self.spellRanksAnnounced = count
	if count > previous then
		self:Print(self:F("SR_CHAT", count))
		if self.ShowNotice and self.WantsNotice and self:WantsNotice() then
			local lines = { self:F("SR_NOTICE", count) }
			for index = 1, math.min(3, count) do
				lines[#lines + 1] = self:F("SR_LINE", list[index].name, list[index].rank, list[index].bestRank)
			end
			if count > 3 then lines[#lines + 1] = self:F("SR_MORE", count - 3) end
			self:ShowNotice({ kind = "spells", color = Theme.ORANGE, lines = lines,
				onClick = function() ns:SpellRanksOpen() end })
		end
	end
	self:SpellRanksRefresh()
	return count
end

-- ---------------------------------------------------------------------------
-- La fenêtre
-- ---------------------------------------------------------------------------
-- hauteur pour `count` lignes (au moins une : la phrase « tout est à jour »)
local function SpellRanksHeight(count)
	return Theme.HEADER_COMPACT_HEIGHT + 1 + GAP + math.max(1, count) * ROW_H - (ROW_H - ROW_CARD)
		+ GAP + Theme.DIALOG_FOOTER
end

function ns:EnsureSpellRanks()
	if self.spellRanksFrame then return self.spellRanksFrame end
	if not (Theme and Theme.CreateDialog) then return nil end
	local frame = Theme.CreateDialog(UIParent, WIDTH, SpellRanksHeight(ns.SPELLRANKS_ROWS), { name = "Ready2QuestSpellRanks",
		title = L.SR_TITLE, subtitle = L.SR_SUB })
	if not frame then return nil end
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	local pad, inner = frame.pad + 1, frame.innerWidth
	local top = frame.contentTop - GAP
	frame.rows = {}
	for index = 1, ns.SPELLRANKS_ROWS do
		local row = Theme.CreateListRow(frame, inner, ROW_CARD, { icon = 24 })
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, top - (index - 1) * ROW_H)
		row:SetIndex(index)
		row.ignore = Theme.CreateButton(row, nil, 24, L.SR_BTN_IGNORE, function() ns:SpellRankIgnore(row.data) end, "outline")
		row.ignore:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.update = Theme.CreateButton(row, nil, 24, L.SR_BTN_UPDATE, function() ns:SpellRankUpdate(row.data) end, "accent")
		row.update:SetPoint("RIGHT", row.ignore, "LEFT", -6, 0)
		local textWidth = inner - row.textLeft - row.update:GetWidth() - row.ignore:GetWidth() - 8 - 6 - 12
		row.text:ClearAllPoints()
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT", row.textLeft, -5)
		row.text:SetWidth(textWidth)
		row.where = Theme.Text(row, Theme.F_SMALL, Theme.MUTED)
		row.where:SetPoint("TOPLEFT", row, "TOPLEFT", row.textLeft, -20)
		row.where:SetWidth(textWidth)
		row.where:SetJustifyH("LEFT")
		row:Hide()
		frame.rows[index] = row
	end
	frame.empty = Theme.Text(frame, Theme.F_BODY, Theme.MUTED_LIGHT)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 12, top - 6)
	frame.empty:SetWidth(inner - 24)
	frame.empty:SetJustifyH("LEFT")
	-- pied : « et N autre(s) » à gauche, « Tout mettre à jour » à droite
	frame.more = Theme.Text(frame.footer, Theme.F_SMALL, Theme.MUTED)
	frame.more:SetPoint("LEFT", frame.footer, "LEFT", Theme.DIALOG_PAD, 0)
	frame.all = frame:AddFooterButton(L.SR_BTN_ALL, function() ns:SpellRankUpdateAll() end, "primary")
	frame:Hide()
	self.spellRanksFrame = frame
	return frame
end

function ns:SpellRanksRefresh()
	-- les liserés suivent (un peu plus tard : une page de barre change d'un coup
	-- des dizaines de cases)
	MarkSoon(0.2)
	local frame = self.spellRanksFrame
	if not (frame and frame:IsShown()) then return nil end
	local list = self:SpellRankScan()
	frame.list = list
	for index, row in ipairs(frame.rows) do
		local entry = list[index]
		row.data = entry
		if entry then
			local icon = Call(C("GetSpellTexture") or Global("GetSpellTexture"), entry.bestID)
			if row.icon.tex then row.icon.tex:SetTexture(icon) end
			row.text:SetText(self:F("SR_LINE", entry.name, entry.rank, entry.bestRank))
			row.where:SetText(self:F("SR_WHERE", entry.bar, entry.case))
			row:Show()
		else
			row:Hide()
		end
	end
	frame.empty:SetText(#list == 0 and L.SR_NONE or "")
	frame.more:SetText(#list > ns.SPELLRANKS_ROWS and self:F("SR_MORE", #list - ns.SPELLRANKS_ROWS) or "")
	if #list > 0 then frame.all:Show() else frame.all:Hide() end
	-- la fenêtre suit la liste : pas de cartes vides sous la dernière
	frame:SetHeight(SpellRanksHeight(math.min(#list, #frame.rows)))
	return list
end

function ns:SpellRanksOpen()
	local frame = self:EnsureSpellRanks()
	if not frame then return nil end
	if self.CloseOtherWindows then self:CloseOtherWindows(frame) end
	frame:Show()
	self:SpellRanksRefresh()
	return frame
end

-- ---------------------------------------------------------------------------
-- Check avant le départ
-- ---------------------------------------------------------------------------
if ns.AddCheck then
	ns.AddCheck{
		-- pas « spellranks » : c'est l'identifiant du module (/r2q module spellranks off)
		id = "barranks",
		inactiveText = "MODULE_INACTIVE",
		active = function() return ModuleOn() end,
		icon = BOOK_ICON,
		weight = 5,
		advice = "ADV_SPELLRANKS",
		label = function() return L.CHK_SPELLRANKS end,
		run = function()
			local count = #ns:SpellRankScan()
			if count == 0 then return true, L.CHK_SPELLRANKS_GOOD, 100 end
			return false, ns:F("CHK_SPELLRANKS_DETAIL", count), 50
		end,
	}
end

-- ---------------------------------------------------------------------------
-- Liseré rouge sur les cases des barres dont le sort a un meilleur rang
-- (cases ignorées exceptées). Un cadre à nous, posé sur le bouton : le bouton
-- sécurisé lui-même n'est jamais touché. Créé hors combat seulement.
-- ---------------------------------------------------------------------------
ns.SPELLRANKS_BUTTONS = {
	{ "ActionButton%d", 12 }, { "MultiBarBottomLeftButton%d", 12 }, { "MultiBarBottomRightButton%d", 12 },
	{ "MultiBarRightButton%d", 12 }, { "MultiBarLeftButton%d", 12 }, { "MultiBar5Button%d", 12 },
	{ "MultiBar6Button%d", 12 }, { "MultiBar7Button%d", 12 },
	{ "BT4Button%d", 180 },           -- Bartender4
	{ "DominosActionButton%d", 180 }, -- Dominos
}
local BORDER_COLOR, BORDER_SIZE = { 1, 0.15, 0.1, 0.95 }, 1.5
local borders = setmetatable({}, { __mode = "k" })   -- bouton -> notre liseré
ns.spellRanksBorders = borders

-- Case d'action affichée par un bouton (page et posture comprises)
function ns.SpellRankButtonSlot(button)
	if type(button) ~= "table" then return nil end
	local slot = tonumber(button.action) or tonumber(button._state_action)
	if slot then return slot end
	if type(button.GetPagedID) == "function" then
		local ok, id = pcall(button.GetPagedID, button)
		if ok and tonumber(id) then return tonumber(id) end
	end
	local paged = Global("ActionButton_GetPagedID")
	if paged then return tonumber((Call(paged, button))) end
	return nil
end

local function Border(button)
	local border = borders[button]
	if border then return border end
	if InCombat() then return nil end
	local ok, frame = pcall(CreateFrame, "Frame", nil, button)
	if not ok or not frame then return nil end
	pcall(frame.SetAllPoints, frame, button)
	if type(button.GetFrameLevel) == "function" then
		pcall(frame.SetFrameLevel, frame, (tonumber((Call(button.GetFrameLevel, button))) or 0) + 5)
	end
	local function Edge(a, b, horizontal)
		local tex = frame:CreateTexture(nil, "OVERLAY")
		tex:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
		tex:SetPoint(a, frame, a)
		tex:SetPoint(b, frame, b)
		if horizontal then tex:SetHeight(BORDER_SIZE) else tex:SetWidth(BORDER_SIZE) end
	end
	pcall(Edge, "TOPLEFT", "TOPRIGHT", true)
	pcall(Edge, "BOTTOMLEFT", "BOTTOMRIGHT", true)
	pcall(Edge, "TOPLEFT", "BOTTOMLEFT", false)
	pcall(Edge, "TOPRIGHT", "BOTTOMRIGHT", false)
	frame:Hide()
	borders[button] = frame
	return frame
end

-- Aperçu des réglages : une mini barre d'action de deux cases, la première
-- à un rang inférieur (liseré rouge, le même que sur les vraies barres,
-- s'il est activé), la seconde à jour
function ns:SpellRanksPreview(container)
	local SLOT = 40
	local slots = {}
	for index, spec in ipairs({ { "Interface\\Icons\\Spell_Holy_HolyBolt", "SR_PREVIEW_OLD" },
		{ "Interface\\Icons\\Spell_Holy_FlashHeal", "SR_PREVIEW_OK" } }) do
		local slot = CreateFrame("Frame", nil, container)
		slot:SetSize(SLOT, SLOT)
		slot:SetPoint("LEFT", container, "LEFT", 22 + (index - 1) * (SLOT + 150), 0)
		slot.bg = Theme.Solid(slot, "BACKGROUND", Theme.INK, 1)
		slot.bg:SetAllPoints()
		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetTexture(spec[1])
		slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
		slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
		if slot.icon.SetTexCoord then slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
		slot.edge = Theme.Border(slot, Theme.EDGE, 1, "BORDER")
		slot.caption = Theme.Text(container, Theme.F_SMALL, Theme.MUTED_LIGHT)
		slot.caption:SetPoint("LEFT", slot, "RIGHT", 10, 0)
		slot.caption:SetText(L[spec[2]])
		slots[index] = slot
	end
	-- liseré rouge des barres (BORDER_COLOR), en quatre traits
	local outline = CreateFrame("Frame", nil, slots[1])
	outline:SetAllPoints(slots[1])
	outline.edges = Theme.Border(outline, BORDER_COLOR, BORDER_COLOR[4], "OVERLAY")
	container.slots, container.outline = slots, outline
	container.hint = Theme.Text(container, Theme.F_SMALL, Theme.MUTED)
	container.hint:SetPoint("LEFT", container, "LEFT", 404, 0)
	container.hint:SetWidth(290)
	container.hint:SetJustifyH("LEFT")
	if container.hint.SetWordWrap then container.hint:SetWordWrap(true) end
	function container:Refresh(addon)
		local on = ModuleOn() and addon:DB().spellranksBorder ~= false
		if on then self.outline:Show() else self.outline:Hide() end
		self.hint:SetText(on and L.SR_PREVIEW_ON or L.SR_PREVIEW_OFF)
	end
	container:Refresh(self)
	return container
end
ns.SPELLRANKS_BORDER_COLOR = BORDER_COLOR

-- Pose ou retire les liserés ; rend le nombre de cases marquées
function ns:SpellRanksMark()
	local slots = {}
	if ModuleOn() and self:DB().spellranksBorder ~= false then
		for _, entry in ipairs(self:SpellRankScan()) do slots[entry.slot] = true end
	end
	local marked = 0
	for _, family in ipairs(ns.SPELLRANKS_BUTTONS) do
		for index = 1, family[2] do
			local button = rawget(_G, string.format(family[1], index))
			if type(button) == "table" then
				local slot = ns.SpellRankButtonSlot(button)
				local want = slot and slots[slot] and (type(button.IsVisible) ~= "function" or button:IsVisible())
				local border = want and Border(button) or borders[button]
				if border then
					if want then border:Show(); marked = marked + 1 else border:Hide() end
				end
			end
		end
	end
	return marked
end

-- ---------------------------------------------------------------------------
-- Événements, commande
-- ---------------------------------------------------------------------------
local HANDLERS = {
	PLAYER_ENTERING_WORLD = function() ns.spellRanksDueAt = ns.Now() + 3 end,
	LEARNED_SPELL_IN_TAB  = function() ns.spellRanksDueAt = ns.Now() + 1 end,
	SPELLS_CHANGED        = function() ns.spellRanksDueAt = ns.spellRanksDueAt or (ns.Now() + 1) end,
	ACTIONBAR_SLOT_CHANGED = function() ns:SpellRanksRefresh() end,
	-- la page ou la posture change : les mêmes boutons montrent d'autres cases
	ACTIONBAR_PAGE_CHANGED = function() MarkSoon(0.2) end,
	UPDATE_BONUS_ACTIONBAR = function() MarkSoon(0.2) end,
	UPDATE_SHAPESHIFT_FORM = function() MarkSoon(0.2) end,
	PLAYER_REGEN_ENABLED  = function()
		if ns.spellRanksPending then ns.spellRanksDueAt = ns.Now() + 1 end
		-- liserés qui n'ont pas pu être créés en combat
		MarkSoon(0.5)
	end,
}
local ok, eventFrame = pcall(CreateFrame, "Frame")
if ok and eventFrame then
	for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		local done, err = pcall(HANDLERS[event], ...)
		if not done and ns.RecordError then ns:RecordError("spellranks:" .. tostring(event), err) end
		ArmDue()
	end)
end
-- Les échéances arrivées ; celle qui reste (posée pendant le passage) est reposée
local function DueRun()
	local now = ns.Now()
	local due = ns.spellRanksDueAt
	if due and now >= due then
		ns.spellRanksDueAt = nil
		local done, err = pcall(ns.SpellRanksCheck, ns)
		if not done and ns.RecordError then ns:RecordError("spellranks:check", err) end
	end
	local mark = ns.spellRanksMarkDueAt
	if mark and now >= mark then
		ns.spellRanksMarkDueAt = nil
		local done, err = pcall(ns.SpellRanksMark, ns)
		if not done and ns.RecordError then ns:RecordError("spellranks:mark", err) end
	end
	ArmDue()
end
function ArmDue()
	local due, mark = ns.spellRanksDueAt, ns.spellRanksMarkDueAt
	local at = (due and mark and math.min(due, mark)) or due or mark
	if at and ns.Soon then ns.Soon("spellranks", math.max(0, at - ns.Now()), DueRun) end
end
if ok and eventFrame then
	ns.spellRanksEventFrame = eventFrame
end

if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["sorts"] = function(self) self:SpellRanksOpen() end
	ns.EXTRA_COMMANDS["spells"] = ns.EXTRA_COMMANDS["sorts"]
end
if type(ns.EXCLUSIVE_WINDOWS) == "table" then table.insert(ns.EXCLUSIVE_WINDOWS, "spellRanksFrame") end

if ns.Mark then ns.Mark("SpellRanks") end
