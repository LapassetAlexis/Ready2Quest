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
local WIDTH, ROW_H = 420, 30
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local FR = {
	OPT_PAGE_SPELLRANKS     = "Rangs de sorts",
	OPT_PAGE_SPELLRANKS_SUB = "Un sort de tes barres a un meilleur rang dans ton livre : tu es prévenu.",
	OPT_SPELLRANKS_ENABLED  = "Activer le module",
	OPT_SPELLRANKS_FORGET   = "Oublier les cases ignorées",
	SR_TITLE                = "Rangs de sorts",
	SR_LINE                 = "%s : rang %d → rang %d",
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
	CHK_SPELLRANKS          = "Sorts des barres à jour",
	CHK_SPELLRANKS_DETAIL   = "%d sort(s) à un rang inférieur sur tes barres",
	ADV_SPELLRANKS          = "Mets à jour les sorts de tes barres (/r2q sorts).",
	HELP_SPELLRANKS         = "/r2q sorts — les sorts de tes barres qui ont un meilleur rang",
}
local EN = {
	OPT_PAGE_SPELLRANKS     = "Spell ranks",
	OPT_PAGE_SPELLRANKS_SUB = "A spell on your bars has a higher rank in your spellbook: you get told.",
	OPT_SPELLRANKS_ENABLED  = "Enable the module",
	OPT_SPELLRANKS_FORGET   = "Forget ignored slots",
	SR_TITLE                = "Spell ranks",
	SR_LINE                 = "%s: rank %d → rank %d",
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
	CHK_SPELLRANKS          = "Bar spells up to date",
	CHK_SPELLRANKS_DETAIL   = "%d spell(s) at a lower rank on your bars",
	ADV_SPELLRANKS          = "Update the spells on your bars (/r2q sorts).",
	HELP_SPELLRANKS         = "/r2q sorts — the spells on your bars that have a higher rank",
}
ns.RegisterStrings(FR, EN)
ns.SPELLRANKS_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({ spellranksEnabled = true })

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "spellranks", title = "OPT_PAGE_SPELLRANKS", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "spellranksEnabled", label = "OPT_SPELLRANKS_ENABLED", kind = "bool" },
			{ key = "spellranksForget", label = "OPT_SPELLRANKS_FORGET", kind = "action" },
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
function ns:EnsureSpellRanks()
	if self.spellRanksFrame then return self.spellRanksFrame end
	if not (Theme and Theme.CreatePanel) then return nil end
	local height = 90 + ns.SPELLRANKS_ROWS * ROW_H
	local frame = Theme.CreatePanel(UIParent, WIDTH, height, L.SR_TITLE, { name = "Ready2QuestSpellRanks" })
	if not frame then return nil end
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	local top = frame.contentTop - 6
	frame.rows = {}
	for index = 1, ns.SPELLRANKS_ROWS do
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(WIDTH - 28, ROW_H - 4)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - (index - 1) * ROW_H)
		row.icon = Theme.CreateIcon(row, 22)
		row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.text = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -1)
		row.text:SetWidth(200)
		row.text:SetJustifyH("LEFT")
		row.where = row:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		row.where:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -14)
		row.where:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		row.update = Theme.CreateButton(row, 92, 20, L.SR_BTN_UPDATE, function() ns:SpellRankUpdate(row.data) end, "primary")
		row.update:SetPoint("RIGHT", row, "RIGHT", -66, 0)
		row.ignore = Theme.CreateButton(row, 60, 20, L.SR_BTN_IGNORE, function() ns:SpellRankIgnore(row.data) end)
		row.ignore:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row:Hide()
		frame.rows[index] = row
	end
	frame.empty = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 4)
	frame.empty:SetWidth(WIDTH - 28)
	frame.empty:SetJustifyH("LEFT")
	frame.more = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.more:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 16)
	frame.more:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	frame.all = Theme.CreateButton(frame, 150, 22, L.SR_BTN_ALL, function() ns:SpellRankUpdateAll() end, "primary")
	frame.all:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
	frame:Hide()
	self.spellRanksFrame = frame
	return frame
end

function ns:SpellRanksRefresh()
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
			if count == 0 then return true, nil, 100 end
			return false, ns:F("CHK_SPELLRANKS_DETAIL", count), 50
		end,
	}
end

-- ---------------------------------------------------------------------------
-- Événements, commande
-- ---------------------------------------------------------------------------
local HANDLERS = {
	PLAYER_ENTERING_WORLD = function() ns.spellRanksDueAt = ns.Now() + 3 end,
	LEARNED_SPELL_IN_TAB  = function() ns.spellRanksDueAt = ns.Now() + 1 end,
	SPELLS_CHANGED        = function() ns.spellRanksDueAt = ns.spellRanksDueAt or (ns.Now() + 1) end,
	ACTIONBAR_SLOT_CHANGED = function() ns:SpellRanksRefresh() end,
	PLAYER_REGEN_ENABLED  = function() if ns.spellRanksPending then ns.spellRanksDueAt = ns.Now() + 1 end end,
}
local ok, eventFrame = pcall(CreateFrame, "Frame")
if ok and eventFrame then
	for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		local done, err = pcall(HANDLERS[event], ...)
		if not done and ns.RecordError then ns:RecordError("spellranks:" .. tostring(event), err) end
	end)
	eventFrame:SetScript("OnUpdate", function()
		local due = ns.spellRanksDueAt
		if not due or ns.Now() < due then return end
		ns.spellRanksDueAt = nil
		local done, err = pcall(ns.SpellRanksCheck, ns)
		if not done and ns.RecordError then ns:RecordError("spellranks:check", err) end
	end)
	ns.spellRanksEventFrame = eventFrame
end

if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["sorts"] = function(self) self:SpellRanksOpen() end
	ns.EXTRA_COMMANDS["spells"] = ns.EXTRA_COMMANDS["sorts"]
end
if type(ns.EXCLUSIVE_WINDOWS) == "table" then table.insert(ns.EXCLUSIVE_WINDOWS, "spellRanksFrame") end

if ns.Mark then ns.Mark("SpellRanks") end
