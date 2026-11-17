-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the one set of settings rows every module's look options are built from (BIT.Looks.Rows).
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The same option (a fill style, a color, an opacity, an outline) used to be built four different ways: DoTInfo's own rows,
-- a copy of them in ShieldsInfo with other widths, and two other widgets in CastPrediction and HealPrediction (a button that
-- cycled, a two-line slider, a checkbox in front of its label). Now there is one of each, with one geometry:
--
--   label on the left (Looks.LAYOUT.label wide), the control at the same column in every module, one line per option
--
--   Rows.Choice(parent, label, list, get, set, opts)    a drop-down: swatch or texture preview, name, "v". Lists made by
--                                                        Looks.ColorList / Looks.Textures also offer their own extras
--   Rows.Slider(parent, label, min, max, step, get, set, opts)   label, slider, value (opts.suffix "%" or opts.display)
--   Rows.Check(parent, label, get, set, opts)           label, then the check box
--   Rows.Button(parent, label, buttonText, onClick, opts)
--   Looks.PresetButton(parent, presets, apply)          the "Look presets v" button (a list of { id, label })
--
-- opts: tooltip, enabledIf(settings) (the row dims and ignores the mouse while it is false), settings() (what enabledIf
-- reads), layout ({ label, control }), register(row) (the module's list of rows to Refresh). Every row has :Refresh().

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Looks = BIT.Looks
local Rows = {}
Looks.Rows = Rows

Looks.LAYOUT = { label = 200, control = 220 }        -- every settings row
Looks.PREVIEW_LAYOUT = { label = 96, control = 140 } -- the rows of a live preview's TRY IT block
Looks.ROW_HEIGHT = 26
local DISABLED_ALPHA = 0.35

local function makeRow(parent, labelText, opts)
    opts = opts or {}
    local layout = opts.layout or Looks.LAYOUT
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(layout.label + layout.control + 60, Looks.ROW_HEIGHT)
    row.layout = layout
    row.standard = true -- the placing code keeps this height whatever it was told
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetWidth(layout.label - 8)
    row.label:SetJustifyH("LEFT")
    if opts.localize then opts.localize(row.label, labelText) else row.label:SetText(BIT.L(labelText)) end
    if BIT.UI and BIT.UI.FitRow then BIT.UI.FitRow(row, Looks.ROW_HEIGHT) end -- a long label wraps and the row grows
    row.enabledIf = opts.enabledIf
    row.settings = opts.settings
    if opts.tooltip or opts.tooltipFor then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local title, body = labelText, opts.tooltip
            if opts.tooltipFor then
                title, body = opts.tooltipFor() -- a localized module builds both at hover time
            elseif not opts.localize then
                title, body = BIT.L(title), BIT.L(body)
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title, 1, 0.82, 0)
            GameTooltip:AddLine(body, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    function row:ApplyEnabled(widget)
        local enabled = true
        if self.enabledIf then
            local ok, result = pcall(self.enabledIf, self.settings and self.settings() or {})
            enabled = not ok or result and true or false
        end
        self:SetAlpha(enabled and 1 or DISABLED_ALPHA)
        if widget then
            widget:EnableMouse(enabled)
            if widget.EnableMouseWheel then widget:EnableMouseWheel(enabled) end
        end
    end
    if opts.register then opts.register(row) end
    return row
end

-- A bare row (label, tooltip, enabled state) for a module's own kind of control: a text box, a read-out.
Rows.Row = makeRow

---------------------------------------------------------------------------------------------
-- Drop-down
---------------------------------------------------------------------------------------------

function Rows.Choice(parent, labelText, list, get, set, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(row.layout.control, 22)
    button:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    if BIT.UI and BIT.UI.SkinButton then BIT.UI.SkinButton(button) end
    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("LEFT", 8, 0)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    local kind = list.kind
    local labelOf = opts.labelOf or function(entry) return entry.literal and entry.label or BIT.L(entry.label) end
    local function entryFor(value)
        if kind == "texture" then Looks.Merge(list) end
        for _, entry in ipairs(list) do
            if entry.id == value then return entry end
        end
        if kind == "color" then
            local entry = Looks.ColorEntry(list, value)
            if entry then return entry end
        end
        if kind == "texture" then return Looks.Texture(value) end
        return nil
    end
    -- Whatever the module does with a pick, this row shows it at once (a module's own setter need not refresh anything).
    local function pick(id)
        set(id)
        row:Refresh()
    end
    button:SetScript("OnClick", function(self)
        if kind == "color" then
            Looks.Choose(self, list, get(), pick)
        else
            if kind == "texture" then Looks.Merge(list) end
            local menuList = list
            if opts.labelOf then -- the menu shows the owner's own names, so the pick list must not translate them again
                menuList = { kind = kind }
                for i, entry in ipairs(list) do
                    local copy = {}
                    for k, v in pairs(entry) do copy[k] = v end
                    copy.label, copy.literal = labelOf(entry), true
                    menuList[i] = copy
                end
            end
            Looks.PickList(self, menuList, get(), pick)
        end
    end)
    function row:Refresh()
        local value = get()
        local entry = entryFor(value)
        text:SetText(entry and labelOf(entry) or tostring(value))
        swatch:SetHorizTile(false)
        swatch:SetVertTile(false)
        local offset = 8
        if entry and entry.rgb then
            swatch:SetSize(14, 12)
            swatch:SetVertexColor(1, 1, 1, 1)
            swatch:SetColorTexture(entry.rgb[1], entry.rgb[2], entry.rgb[3], 1)
            swatch:Show()
            offset = 28
        elseif entry and entry.path and kind == "icon" then
            swatch:SetSize(16, 16)
            swatch:SetVertexColor(1, 1, 1, 1)
            swatch:SetTexture(entry.path)
            swatch:Show()
            offset = 30
        elseif entry and entry.path then
            swatch:SetSize(34, 12)
            swatch:SetTexture(entry.path, entry.tiled and "REPEAT" or nil, entry.tiled and "REPEAT" or nil)
            swatch:SetHorizTile(entry.tiled or false)
            swatch:SetVertTile(entry.tiled or false)
            if entry.raw then swatch:SetVertexColor(1, 1, 1, 1) else swatch:SetVertexColor(1, 0.62, 0.2, 1) end
            swatch:Show()
            offset = 48
        else
            swatch:Hide()
        end
        text:ClearAllPoints()
        text:SetPoint("LEFT", offset, 0)
        text:SetPoint("RIGHT", -20, 0)
        self:ApplyEnabled(button)
    end
    row.widget = button
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------------------------

function Rows.Slider(parent, labelText, min, max, step, get, set, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(row.layout.control - 44, 18)
    slider:SetPoint("LEFT", row, "LEFT", row.layout.label + 2, 0)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb and thumb.SetSize then thumb:SetSize(18, 24) end
    if BIT.UI and BIT.UI.SkinSlider then BIT.UI.SkinSlider(slider, 6) end
    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    local suffix = opts.suffix or ""
    local function show(value)
        if opts.display or opts.format then
            valueText:SetText((opts.display or opts.format)(value))
        elseif step < 1 then
            valueText:SetText(string.format("%.2f", value) .. suffix)
        else
            valueText:SetText(string.format("%d", math.floor(value + 0.5)) .. suffix)
        end
    end
    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        show(value)
        if updating then return end
        set(value)
    end)
    slider:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)
    function row:Refresh()
        updating = true
        local value = get()
        slider:SetValue(value)
        show(math.floor(value / step + 0.5) * step)
        updating = false
        self:ApplyEnabled(slider)
    end
    row.widget = slider
    row:Refresh()
    return row
end

---------------------------------------------------------------------------------------------
-- Check box and button
---------------------------------------------------------------------------------------------

function Rows.Check(parent, labelText, get, set, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local box = CreateFrame("CheckButton", nil, row)
    box:SetSize(24, 24)
    box:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    if BIT.UI and BIT.UI.SkinCheck then BIT.UI.SkinCheck(box) end
    box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function row:Refresh()
        box:SetChecked(get() and true or false)
        self:ApplyEnabled(box)
    end
    row.widget = box
    row:Refresh()
    return row
end

function Rows.Button(parent, labelText, buttonText, onClick, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(row.layout.control, 22)
    button:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    if BIT.UI and BIT.UI.SkinButton then BIT.UI.SkinButton(button) end
    button:SetText(BIT.L(buttonText))
    button:SetScript("OnClick", function() onClick() end)
    function row:Refresh() self:ApplyEnabled(button) end
    row.widget = button
    return row
end

---------------------------------------------------------------------------------------------
-- The look presets button
---------------------------------------------------------------------------------------------

-- A "Look presets v" button; a pick calls apply(preset) for the entry of `presets` (a list of { id, label, ... }).
function Looks.PresetButton(parent, presets, apply, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 140, 22)
    if BIT.UI and BIT.UI.SkinButton then BIT.UI.SkinButton(button) end
    button:SetText(BIT.L("Look presets  v"))
    button:SetWidth(math.max(width or 140, button:GetFontString():GetStringWidth() + 24))
    button:SetScript("OnClick", function(self)
        local list = {}
        for _, preset in ipairs(presets) do list[#list + 1] = { id = preset.id or preset.label, label = preset.label } end
        Looks.PickList(self, list, nil, function(id)
            for _, preset in ipairs(presets) do
                if (preset.id or preset.label) == id then apply(preset) end
            end
        end)
    end)
    return button
end

-- The "Reset this tab" button every settings tab ends with (a module that keeps its tab keys calls onClick to restore them).
function Looks.ResetButton(parent, onClick, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 22)
    if BIT.UI and BIT.UI.SkinButton then BIT.UI.SkinButton(button) end
    button:SetText(BIT.L("Reset this tab"))
    button:SetWidth(math.max(width or 120, button:GetFontString():GetStringWidth() + 24))
    button:SetScript("OnClick", function() onClick() end)
    return button
end

-- The "TRY IT" heading above the preview's own sliders (the sample's numbers, never settings).
function Looks.TryItHeader(parent, anchor, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 4, y or -12)
    text:SetText(BIT.L("TRY IT"))
    text:SetTextColor(1, 0.82, 0)
    return text
end

-- A preview slider: the same inline row as everywhere else, in the narrower preview geometry, shown as a percentage.
function Looks.PreviewSlider(parent, labelText, min, max, get, set)
    return Rows.Slider(parent, labelText, min, max, 1, get, set, { layout = Looks.PREVIEW_LAYOUT, suffix = "%" })
end
