-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: the learned tick sizes viewer (Behavior tab > View, /dotinfo ticks). From
-- Does It Die v0.7.0's Options.lua by Joe Greive (MIT).
-- One row per learned tick size, with the spell's icon, name and rank (hover for its tooltip, shift-click to link
-- it), what its description predicts per tick, and the difference: the spell power or attack power the description
-- leaves out. Forever only: Retail doesn't learn tick sizes from hits.

local ADDON_NAME, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Ready2QuestCombat's own namespace for the module, shared by its files.
local ns = BIT.Module("DoTInfo")

if ns.Retail then return end

local ROW_HEIGHT, VISIBLE_ROWS = 32, 11
-- Column x positions and widths in a row; numbers are right-aligned in theirs.
local COLUMNS = {
    spell = { 44, 212 }, combo = { 258, 48 }, learned = { 310, 66 }, tooltip = { 380, 66 }, bonus = { 450, 58 },
    total = { 512, 70 },
}
local SPELL_LINK_COLOR = { 0.44, 0.84, 1 }
local viewer

local function formatTick(value)
    if not value then return "-" end
    if value == math.floor(value) then return string.format("%d", value) end
    return string.format("%.1f", value)
end

local function spellCall(fnName, spellID)
    local fn = C_Spell and C_Spell[fnName]
    if not fn then return nil end
    local ok, value = pcall(fn, spellID)
    if ok and (type(value) == "string" or type(value) == "number") then return value end
end

local function spellLink(spellID)
    local link = spellCall("GetSpellLink", spellID)
    if not link and GetSpellLink then
        local ok, value = pcall(GetSpellLink, spellID)
        link = ok and value or nil
    end
    return link
end

local function pushButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(BIT.L(text))
    -- A longer translation widens the button instead of overflowing it.
    button:SetSize(math.max(width, math.ceil(button:GetFontString():GetStringWidth()) + 20), 22)
    button:SetScript("OnClick", onClick)
    return BIT.UI.SkinButton(button)
end

-- What SpellDamageInfo recorded of the player's casts (Blizzard's damage meter, read after each fight): per spell the
-- average damage or healing of a cast over the last 100 casts, beside the description's own figure. A DoT or HoT counts
-- everything it did within the fights; healing is what the meter counts. { key, spellID, name, perTick = per cast,
-- tooltipPerTick = the description's figure, casts, healing, color } sorted by casts.
local DAMAGE_COLOR, HEAL_COLOR = { 1, 0.82, 0.2 }, { 0.4, 1, 0.4 }
local function castList()
    local list = {}
    local sdi = BIT.modules and BIT.modules.SpellDamageInfo
    if type(sdi) ~= "table" or type(sdi.History) ~= "table" then return list end
    for _, row in ipairs(sdi.History.List()) do
        local healing = row.healing > row.damage
        local entry = { key = row.id, spellID = row.id, name = row.name, casts = row.casts, healing = healing,
            perTick = healing and row.healing or row.damage, color = healing and HEAL_COLOR or DAMAGE_COLOR }
        if type(sdi.DescriptionTotals) == "function" then
            local ok, damage, heal = pcall(sdi.DescriptionTotals, row.id)
            if ok and damage then entry.tooltipPerTick = (healing and heal or damage) > 0 and (healing and heal or damage) or nil end
        end
        list[#list + 1] = entry
    end
    return list
end

local function showTooltip(row)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local shown = GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, entry.spellID)
    if not shown then GameTooltip:SetText(entry.name or string.format(BIT.L("Spell %d"), entry.spellID), 1, 1, 1) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("DoTInfo", 1, 0.82, 0)
    if entry.casts then
        GameTooltip:AddDoubleLine(BIT.L(entry.healing and "Healing per cast" or "Damage per cast"), formatTick(entry.perTick),
            0.8, 0.8, 0.8, 1, 1, 1)
        if entry.tooltipPerTick then
            GameTooltip:AddDoubleLine(BIT.L("Tooltip, one cast"), formatTick(entry.tooltipPerTick), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine(BIT.L("Casts recorded"), string.format("%d", entry.casts), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(BIT.L("The average of your last 100 casts: misses, resists and crits are in it, a DoT or HoT counts "
            .. "what it did while you were in combat, and healing is what the damage meter counts."), 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(BIT.L("Shift-click to link it in chat."), 0.5, 0.8, 1)
        GameTooltip:Show()
        return
    end
    if entry.comboPoints then
        GameTooltip:AddDoubleLine(BIT.L("Combo points"), entry.comboPoints, 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(BIT.L("Learned per tick"), formatTick(entry.perTick), 0.8, 0.8, 0.8, 1, 1, 1)
    if entry.tooltipPerTick then
        GameTooltip:AddDoubleLine(BIT.L("Tooltip per tick"), formatTick(entry.tooltipPerTick), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(BIT.L("Ticks"), string.format(BIT.L("%d, every %gs (%gs)"), entry.ticks,
            entry.interval, entry.duration), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(BIT.L("Full duration"), formatTick(entry.perTick * entry.ticks), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddLine(BIT.L("Learned from this spell's ticks on your targets; used instead of the tooltip's number, "
        .. "which leaves out spell power and attack power."), 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(BIT.L("Shift-click to link it in chat."), 0.5, 0.8, 1)
    GameTooltip:Show()
end

local function createRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.035 or 0)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    -- The spell's school color, as on the marker with "By spell school".
    row.school = row:CreateTexture(nil, "ARTWORK")
    row.school:SetSize(3, ROW_HEIGHT - 8)
    row.school:SetPoint("LEFT", 2, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 12, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", COLUMNS.spell[1], -3)
    row.name:SetWidth(COLUMNS.spell[2])
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.rank:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    row.rank:SetWidth(COLUMNS.spell[2])
    row.rank:SetJustifyH("LEFT")
    row.cells = {}
    for _, column in ipairs({ "combo", "learned", "tooltip", "bonus", "total" }) do
        local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cell:SetPoint("LEFT", row, "LEFT", COLUMNS[column][1], 0)
        cell:SetWidth(COLUMNS[column][2])
        cell:SetJustifyH(column == "combo" and "CENTER" or "RIGHT")
        row.cells[column] = cell
    end

    local forget = CreateFrame("Button", nil, row)
    forget:SetSize(20, 20)
    forget:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    forget.text = forget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    forget.text:SetPoint("CENTER")
    forget.text:SetText("x")
    forget.text:SetTextColor(0.6, 0.6, 0.6)
    local forgetHighlight = forget:CreateTexture(nil, "HIGHLIGHT")
    forgetHighlight:SetAllPoints()
    forgetHighlight:SetColorTexture(1, 0.3, 0.3, 0.25)
    forget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local casts = viewer and viewer.mode == "casts"
        GameTooltip:SetText(BIT.L(casts and "Forget this spell's casts" or "Forget this tick size"), 1, 1, 1)
        GameTooltip:AddLine(BIT.L(casts and "Its recorded casts are deleted; the next fights start them again."
            or "The next cast starts from the tooltip again and learns it anew."), nil, nil, nil, true)
        GameTooltip:Show()
    end)
    forget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    forget:SetScript("OnClick", function()
        if not row.entry then return end
        if row.entry.casts then
            local sdi = BIT.modules and BIT.modules.SpellDamageInfo
            if sdi and sdi.History then sdi.History.Forget(row.entry.spellID) end
        else
            ns.forgetLearnedTick(row.entry.key)
        end
        viewer:Refresh()
    end)

    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if not (self.entry and IsShiftKeyDown and IsShiftKeyDown()) then return end
        local link = spellLink(self.entry.spellID)
        if link and not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then
            ChatFrame_OpenChat(link)
        end
    end)
    return row
end

local function fillRow(row, entry)
    row.entry = entry
    local color = entry.color or { 0.5, 0.5, 0.5 }
    row.school:SetColorTexture(color[1], color[2], color[3], 1)
    row.icon:SetTexture(spellCall("GetSpellTexture", entry.spellID) or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText(entry.name or string.format(BIT.L("Spell %d"), entry.spellID))
    row.name:SetTextColor(SPELL_LINK_COLOR[1], SPELL_LINK_COLOR[2], SPELL_LINK_COLOR[3])
    local rank = spellCall("GetSpellSubtext", entry.spellID)
    row.rank:SetText(rank and rank ~= "" and rank or string.format(BIT.L("ID %d"), entry.spellID))
    row.cells.combo:SetText(entry.comboPoints or "")
    row.cells.learned:SetText(formatTick(entry.perTick))
    row.cells.tooltip:SetText(entry.tooltipPerTick and formatTick(entry.tooltipPerTick) or "-")
    local bonus = entry.tooltipPerTick and entry.tooltipPerTick > 0
        and math.floor((entry.perTick / entry.tooltipPerTick - 1) * 100 + 0.5)
    if bonus then
        row.cells.bonus:SetText(string.format("%+d%%", bonus))
        if bonus > 0 then
            row.cells.bonus:SetTextColor(0.4, 1, 0.4)
        elseif bonus < 0 then
            row.cells.bonus:SetTextColor(1, 0.45, 0.45)
        else
            row.cells.bonus:SetTextColor(0.7, 0.7, 0.7)
        end
    else
        row.cells.bonus:SetText("-")
        row.cells.bonus:SetTextColor(0.7, 0.7, 0.7)
    end
    if entry.casts then
        row.cells.total:SetText(string.format("%d", entry.casts))
    else
        row.cells.total:SetText(entry.ticks and formatTick(entry.perTick * entry.ticks) or "-")
    end
    row:Show()
end

local function createViewer()
    local width = COLUMNS.total[1] + COLUMNS.total[2] + 56
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(width, 112 + VISIBLE_ROWS * ROW_HEIGHT + 44)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    BIT.UI.Backdrop(frame, 0.06, 0.97)

    -- Escape closes it, without adding to Blizzard's UISpecialFrames: the key goes to this frame while it's shown
    -- and passes on to the game otherwise. SetPropagateKeyboardInput is a protected function in combat (calling it
    -- there was an ADDON_ACTION_BLOCKED on every key pressed while the window was open in a fight), so it is only
    -- touched out of combat; in combat the window takes no keys at all, which cannot swallow a binding.
    local function inCombat() return InCombatLockdown and InCombatLockdown() end
    local function takeKeys(self)
        if inCombat() then
            self:EnableKeyboard(false)
        else
            self:EnableKeyboard(true)
            self:SetPropagateKeyboardInput(true)
        end
    end
    takeKeys(frame)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and not inCombat() then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(BIT.L("Learned tick sizes"))
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -10)
    local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(width - 32)
    intro:SetJustifyH("LEFT")
    intro:SetText(BIT.L("What each DoT really ticks for, learned from your casts and used instead of its tooltip. "
        .. "Tooltips leave out spell power and attack power: Bonus is how much more yours do. "
        .. "Hover a spell for details, shift-click to link it."))

    local list = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", 10, -100)
    list:SetPoint("TOPRIGHT", -10, -100)
    list:SetHeight(VISIBLE_ROWS * ROW_HEIGHT + 2)
    BIT.UI.Backdrop(list, 0.09)
    list:EnableMouseWheel(true)

    local headers = { spell = BIT.L("Spell"), combo = BIT.L("Combo"), learned = BIT.L("Per tick"),
        tooltip = BIT.L("Tooltip"), bonus = BIT.L("Bonus"), total = BIT.L("Total") }
    frame.headers = {}
    for column, text in pairs(headers) do
        local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.headers[column] = header
        header:SetPoint("BOTTOMLEFT", list, "TOPLEFT", COLUMNS[column][1], 4)
        header:SetWidth(COLUMNS[column][2])
        header:SetJustifyH(column == "spell" and "LEFT" or column == "combo" and "CENTER" or "RIGHT")
        header:SetText(text)
    end

    frame.rows = {}
    for i = 1, VISIBLE_ROWS do
        frame.rows[i] = createRow(list, i)
        frame.rows[i]:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1 - (i - 1) * ROW_HEIGHT)
        frame.rows[i]:SetPoint("RIGHT", list, "RIGHT", -1, 0)
    end
    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER")
    empty:SetWidth(width - 80)
    empty:SetText(BIT.L("Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."))

    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("BOTTOMLEFT", 16, 18)
    local forgetAll = pushButton(frame, "Forget all", 100, function()
        ns.resetLearnedTicks()
        frame:Refresh()
    end)
    forgetAll:SetPoint("BOTTOMRIGHT", -12, 12)

    frame.mode = "ticks" -- or "casts": what SpellDamageInfo recorded of every spell's casts
    local toggle = pushButton(frame, "Show casts and heals", 170, function()
        frame.mode = frame.mode == "casts" and "ticks" or "casts"
        frame.offset = 0
        frame:Refresh()
    end)
    toggle:SetPoint("RIGHT", forgetAll, "LEFT", -8, 0)
    frame.toggle = toggle
    forgetAll:SetScript("OnClick", function()
        if frame.mode == "casts" then
            local sdi = BIT.modules and BIT.modules.SpellDamageInfo
            if sdi and sdi.History then sdi.History.Clear() end
        else
            ns.resetLearnedTicks()
        end
        frame:Refresh()
    end)

    frame.offset = 0
    function frame:Refresh()
        local casts = self.mode == "casts"
        local entries = casts and castList() or ns.learnedTickList()
        self.headers.combo:SetText(casts and "" or headers.combo)
        self.headers.learned:SetText(BIT.L(casts and "Per cast" or "Per tick"))
        self.headers.total:SetText(BIT.L(casts and "Casts" or "Total"))
        intro:SetText(BIT.L(casts and "What your casts of each spell really did, averaged over the last 100: damage and healing "
            .. "from Blizzard's damage meter, read after each fight. Bonus is how much more yours do than the tooltip says. "
            .. "Hover a spell for details, shift-click to link it." or "What each DoT really ticks for, learned from your casts and used instead of its tooltip. "
            .. "Tooltips leave out spell power and attack power: Bonus is how much more yours do. "
            .. "Hover a spell for details, shift-click to link it."))
        empty:SetText(BIT.L(casts and "Nothing recorded yet. Casts are recorded after each fight, once the damage meter can be read."
            or "Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."))
        toggle:SetText(BIT.L(casts and "Show DoT ticks" or "Show casts and heals"))
        local maxOffset = math.max(0, #entries - VISIBLE_ROWS)
        self.offset = math.max(0, math.min(self.offset, maxOffset))
        for i, row in ipairs(self.rows) do
            local entry = entries[self.offset + i]
            if entry then fillRow(row, entry) else row.entry = nil; row:Hide() end
        end
        empty:SetShown(#entries == 0)
        local scrolled = maxOffset > 0 and "  " .. string.format(BIT.L("(%d-%d shown; scroll for more)"),
            self.offset + 1, math.min(#entries, self.offset + VISIBLE_ROWS)) or ""
        local counted = casts and string.format(BIT.L("%d spells recorded"), #entries)
            or (#entries == 1 and BIT.L("1 learned tick size") or string.format(BIT.L("%d learned tick sizes"), #entries))
        count:SetText(counted .. scrolled)
        forgetAll:SetEnabled(#entries > 0)
    end
    list:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = frame.offset - delta
        frame:Refresh()
    end)
    -- New ticks are learned while it's open (in combat): keep it current.
    local sinceRefresh = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        sinceRefresh = sinceRefresh + elapsed
        if sinceRefresh < 1 then return end
        sinceRefresh = 0
        self:Refresh()
    end)
    frame:SetScript("OnShow", function(self)
        sinceRefresh = 0
        takeKeys(self) -- Escape turned propagation off when it closed the window; and a fight may have begun since
        self:Refresh()
    end)
    return frame
end

function ns.toggleTickViewer()
    if not ns.db then return end
    if not viewer then viewer = createViewer() end
    if viewer:IsShown() then return viewer:Hide() end
    viewer:ClearAllPoints()
    viewer:SetPoint("CENTER")
    viewer:Show()
end
