-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: options window. Based on the standalone DoT addon's options
-- at e4faef4 by Joe Greive (MIT); it lives only here now and is edited directly.
-- DoTInfo options window (/dotinfo).
--
-- Left: a live preview. The addon's real marker and kill icon are attached to a mock target frame here (see
-- ns.setDisplayHost in Core.lua) and fed plain numbers from the preview sliders, so the preview runs the
-- same drawing code as combat. Right: tabbed settings. Top: presets.
--
-- Controls are built from basic widgets (CheckButton, Slider, Button) rather than Blizzard templates, so they
-- don't depend on templates behaving the same in Forever. Settings are written straight to ns.db.

local ADDON_NAME, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Ready2QuestCombat's own namespace for the module, shared by its four files.
local ns = BIT.Module("DoTInfo")

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WINDOW_WIDTH, WINDOW_HEIGHT = 760, 626 -- two tab rows plus the longest page (Nameplates, 17 rows)
local HEADER_HEIGHT = 52 -- title bar: title, presets, close button
local TAB_HEIGHT = 26
local PREVIEW_WIDTH = 290
local ROW_HEIGHT = 26
local SETTINGS_LAYOUT = BIT.Looks.LAYOUT -- one geometry for every module's rows (Core/LookRows.lua)
local PREVIEW_LAYOUT = BIT.Looks.PREVIEW_LAYOUT
local DISABLED_ALPHA = 0.35
local SIMULATION_STEP = 0.5 -- seconds

-- Presets style both the target marker and nameplates; accuracy settings are left alone.
local PRESETS = {
    { id = "minimal", label = "Minimal", values = {
        showSkull = true, skullIcon = "cross", skullSize = 40, skullPulse = false,
        showMarkers = true, fillTexture = "flat", fillColor = "purple", fillOpacity = 35, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "purple", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "classic", label = "Classic", values = {
        showSkull = true, skullIcon = "skull", skullSize = 48, skullPulse = true,
        showMarkers = true, fillTexture = "smooth", fillColor = "red", fillOpacity = 60, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 2, outlineColor = "gold", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = false,
        showSpark = true, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "juicy", label = "Juicy", values = {
        showSkull = true, skullIcon = "shades", skullSize = 64, skullPulse = true,
        showMarkers = true, fillTexture = "stripes", fillColor = "red", fillOpacity = 100, dotColors = "each",
        segmentDividers = true, outlineStyle = "dashed", dashLength = 4, outlineThickness = 1, outlineColor = "red",
        outlineOpacity = 85, smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 7, showShine = true, shineInterval = 3, scrollStripes = true,
        showLabel = false,
    } },
    { id = "glass", label = "Glass", values = {
        showSkull = true, skullIcon = "boss", skullSize = 44, skullPulse = false,
        showMarkers = true, fillTexture = "gloss", fillColor = "sky", fillOpacity = 85, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "ice", outlineOpacity = 90,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = true, glowSize = 4, showShine = true, shineInterval = 4, scrollStripes = false,
        showLabel = false,
    } },
    { id = "neon", label = "Neon", values = {
        showSkull = true, skullIcon = "skull", skullSize = 56, skullPulse = true,
        showMarkers = true, fillTexture = "scanlines", fillColor = "magenta", fillOpacity = 90, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 2, outlineColor = "cyan", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 10, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "blood", label = "Blood", values = {
        showSkull = true, skullIcon = "skull", skullSize = 56, skullPulse = true,
        showMarkers = true, fillTexture = "cylinder", fillColor = "crimson", fillOpacity = 95, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "maroon", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = false,
        showSpark = true, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "frost", label = "Frost", values = {
        showSkull = true, skullIcon = "cross", skullSize = 44, skullPulse = false,
        showMarkers = true, fillTexture = "noise", fillColor = "ice", fillOpacity = 75, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "sky", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = true, glowSize = 5, showShine = true, shineInterval = 5, scrollStripes = false,
        showLabel = false,
    } },
    { id = "toxic", label = "Toxic", values = {
        showSkull = true, skullIcon = "check", skullSize = 48, skullPulse = true,
        showMarkers = true, fillTexture = "waves", fillColor = "lime", fillOpacity = 80, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 1, outlineColor = "forest", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = false, showGlow = true, glowSize = 6, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "carbon", label = "Carbon", values = {
        showSkull = true, skullIcon = "boss", skullSize = 48, skullPulse = false,
        showMarkers = true, fillTexture = "carbon", fillColor = "charcoal", fillOpacity = 95, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "gold", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = true, shineInterval = 6, scrollStripes = false, showLabel = false,
    } },
    { id = "ember", label = "Ember", values = {
        showSkull = true, skullIcon = "skull", skullSize = 52, skullPulse = true,
        showMarkers = true, fillTexture = "bevel", fillColor = "amber", fillOpacity = 90, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 2, outlineColor = "orange", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 7, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "debug", label = "Debug", values = {
        showSkull = true, skullIcon = "cross", skullPulse = false,
        showMarkers = true, fillTexture = "flat", fillOpacity = 60, dotColors = "each", segmentDividers = true,
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "white", outlineOpacity = 100,
        smoothMotion = false, flashOnApply = true, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = false, scrollStripes = false,
        showLabel = true, labelPosition = "left", labelSize = 10, labelColor = "white",
    } },
}

local window
local controls = {} -- every settings/preview row, refreshed after each change
local tabs, activeTab = {}, nil
local menu -- shared dropdown list
local simulation

-- Preview numbers, in % of the mock target's max health.
local preview = {
    health = 60,
    dots = {
        { name = "Corruption", school = 32, damage = 27, tick = 4, refreshDue = true },
        { name = "Immolate", school = 4, damage = 18, tick = 5 },
    },
}

local function db() return ns.db end

local function findEntry(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
end

local function setBackdrop(frame, shade, alpha)
    BIT.UI.Backdrop(frame, shade, alpha)
end

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------

local function previewTotal()
    local total = 0
    for _, dot in ipairs(preview.dots) do total = total + dot.damage end
    return total
end

-- Splits a total over the two sample DoTs (60/40).
local function setPreviewDamage(total)
    preview.dots[1].damage = total * 0.6
    preview.dots[2].damage = total * 0.4
end

local function refreshControls()
    for _, control in ipairs(controls) do control:Refresh() end
end

local function inCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

-- The preview only takes over the display out of combat: in combat the real target comes first, even with the
-- window open (settings changes still apply to it live).
local function syncDisplayHost()
    -- Visible, not just shown: when the window is built into another addon's settings (Ready2QuestCombat), its
    -- own frame stays "shown" while the settings around it are closed, and the end of a fight then put the
    -- marker back on the preview's mock target frame, drawn where the closed window had been.
    if not window or not window:IsVisible() then return end
    local paused = inCombat() and true or false
    window.combatNote:SetShown(paused)
    window.mock:SetAlpha(paused and 0.3 or 1)
    window.mockPlate:SetAlpha(paused and 0.3 or 1)
    window.simulateButton:SetEnabled(not paused)
    window.flashButton:SetEnabled(not paused)
    if paused ~= window.previewPaused then
        window.previewPaused = paused
        if paused and simulation then
            simulation:Cancel()
            simulation = nil
            window.simulateButton:SetText(BIT.L("Simulate fight"))
        end
        ns.setDisplayHost((not paused) and window.host or nil)
        ns.setPlatePreview((not paused) and window.plateHost or nil, preview)
    end
end

-- The verdict badge under the preview scene: one look per outcome.
local VERDICT_STYLES = {
    none = { icon = "Interface\\Common\\Indicator-Gray",
        bg = { 0.11, 0.11, 0.12 }, edge = { 0.32, 0.32, 0.34 }, text = { 0.72, 0.72, 0.72 } },
    survives = { icon = "Interface\\Common\\Indicator-Yellow",
        bg = { 0.19, 0.14, 0.04 }, edge = { 0.85, 0.62, 0.12 }, text = { 1, 0.82, 0.35 } },
    lethal = { icon = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", -- when the chosen kill icon has no path
        bg = { 0.05, 0.19, 0.07 }, edge = { 0.30, 0.85, 0.35 }, text = { 0.55, 1, 0.55 } },
    dead = { icon = "Interface\\RaidFrame\\ReadyCheck-Ready",
        bg = { 0.10, 0.13, 0.10 }, edge = { 0.35, 0.50, 0.35 }, text = { 0.70, 0.85, 0.70 } },
}
local PREVIEW_MAX_HEALTH = 142 -- the mock murloc's health, for the number on its bar

-- The kill icon picked in the settings, so the badge shows the same icon the portrait gets.
local function chosenKillIcon()
    local entry = ns.findById and ns.lists and ns.findById(ns.lists.icons, db().skullIcon)
    return entry and entry.path or VERDICT_STYLES.lethal.icon
end

local function setVerdict(kind, text, detail)
    local style = VERDICT_STYLES[kind]
    local badge = window.statusBadge
    badge:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], 0.95)
    badge:SetBackdropBorderColor(style.edge[1], style.edge[2], style.edge[3], 0.9)
    badge.accent:SetColorTexture(style.edge[1], style.edge[2], style.edge[3], 1)
    badge.icon:SetTexture(kind == "lethal" and chosenKillIcon() or style.icon)
    window.status:SetText(text)
    window.status:SetTextColor(style.text[1], style.text[2], style.text[3])
    window.statusDetail:SetText(detail or "")
end

local function updatePreview()
    if not window then return end
    window.healthBar:SetValue(preview.health)
    window.plateHealthBar:SetValue(preview.health)
    local total, health = previewTotal(), preview.health
    local function pct(value) return math.floor(value + 0.5) .. "%" end
    -- The numbers the game's own target frame shows on its bar: percent left, health right.
    window.healthPercent:SetText(pct(health))
    window.healthValue:SetText(tostring(math.floor(PREVIEW_MAX_HEALTH * health / 100 + 0.5)))
    if health <= 0 then
        setVerdict("dead", BIT.L("Target died"), "")
    elseif total <= 0 then
        setVerdict("none", BIT.L("No DoTs on the target"), "")
    elseif total * (tonumber(ns.db and ns.db.killMargin) or 100) / 100 >= health then
        setVerdict("lethal", BIT.L("DoTs kill it"), string.format(BIT.L("%s vs %s"), pct(total), pct(health)))
    else
        setVerdict("survives", string.format(BIT.L("Survives by %s"), pct(health - total)),
            string.format(BIT.L("%s vs %s"), pct(total), pct(health)))
    end
    ns.refresh()
end

local function stopSimulation()
    if simulation then
        simulation:Cancel()
        simulation = nil
    end
    if window then window.simulateButton:SetText(BIT.L("Simulate fight")) end
end

-- A scripted fight: a DoT lands, ticks, a second DoT lands and makes it lethal, ticks until the target dies.
local function startSimulation()
    stopSimulation()
    preview.health = 80
    setPreviewDamage(0)
    local step = 0
    simulation = C_Timer.NewTicker(SIMULATION_STEP, function()
        step = step + 1
        if step == 1 then
            preview.dots[1].damage = 32
            ns.playFlash()
        elseif step == 5 then
            preview.dots[2].damage = 50
            ns.playFlash()
        else
            local dealt = 0
            for _, dot in ipairs(preview.dots) do
                local tick = math.min(dot.damage, dot.tick)
                dot.damage = dot.damage - tick
                dealt = dealt + tick
            end
            preview.health = math.max(0, preview.health - dealt)
        end
        updatePreview()
        refreshControls()
        if preview.health <= 0 or (step > 5 and previewTotal() <= 0) then stopSimulation() end
    end)
    window.simulateButton:SetText(BIT.L("Stop"))
    updatePreview()
    refreshControls()
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

local function changed()
    updatePreview()
    refreshControls()
end

local rowOpts -- below
local function makeRow(parent, labelText, opts)
    return BIT.Looks.Rows.Row(parent, labelText, rowOpts(opts))
end

rowOpts = function(opts)
    opts = opts or {}
    return { tooltip = opts.tooltip, enabledIf = opts.enabledIf, layout = opts.layout, suffix = opts.suffix,
        display = opts.display, settings = db, register = function(row) table.insert(controls, row) end }
end

-- The check box, slider and drop-down are the shared rows (Core/LookRows.lua): every module's options look the same.
local function checkbox(parent, key, labelText, opts)
    return BIT.Looks.Rows.Check(parent, labelText, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, rowOpts(opts))
end

-- get/set work on any value (settings or preview numbers).
local function sliderRow(parent, labelText, min, max, step, get, set, opts)
    return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, get, set, rowOpts(opts))
end

local function slider(parent, key, labelText, min, max, step, opts)
    return sliderRow(parent, labelText, min, max, step,
        function() return db()[key] end,
        function(value)
            db()[key] = value
            changed()
        end, opts)
end

local function closeMenu()
    if BIT.Looks then BIT.Looks.ClosePickList() end
end

-- The shared drop-down (Core/Looks.lua): scrolls, shows a swatch or a texture preview, groups entries.
local function openMenu(owner, list, current, pick)
    BIT.Looks.PickList(owner, list, current, pick)
end

local function choice(parent, key, labelText, list, opts)
    local menuList = list
    if list == ns.lists.colors then menuList = BIT.Looks.ColorList() end
    return BIT.Looks.Rows.Choice(parent, labelText, menuList, function() return db()[key] end, function(id)
        db()[key] = id
        changed()
    end, rowOpts(opts))
end

local function pushButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(BIT.L(text))
    -- A longer translation widens the button instead of overflowing it.
    button:SetSize(math.max(width, math.ceil(button:GetFontString():GetStringWidth()) + 20), 22)
    button:SetScript("OnClick", onClick)
    return BIT.UI.SkinButton(button)
end

local function actionRow(parent, labelText, buttonText, onClick, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local button = pushButton(row, buttonText, 90, onClick)
    button:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    function row:Refresh() self:ApplyEnabled(button) end
    return row
end

-- A frame path (Core/Frames.lua): a text box, saved on Enter or leaving it, and a Pick button that takes the next
-- click on screen. kind: "bar" or "anchor". key: the Frames setting ("target", "icon", "focus", "plate").
local function frameRow(parent, key, labelText, kind, opts)
    opts = opts or {}
    local row = makeRow(parent, labelText, opts)
    local Frames = BIT.Frames
    local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    box:SetSize(row.layout.control - (opts.noPick and 0 or 58), 22)
    box:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
    setBackdrop(box, 0.13)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    local function save(value)
        Frames.Set(key, value)
        changed()
    end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(Frames.Get(key))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if strtrim(self:GetText() or "") ~= Frames.Get(key) then save(self:GetText()) end
    end)
    local pick = (not opts.noPick) and pushButton(row, "Pick", 52, function()
        ns.print(kind == "bar"
            and BIT.L("Click the health bar (you may need to move this window). Right-click cancels.")
            or BIT.L("Click where the kill icon should go (you may need to move this window). Right-click cancels."))
        Frames.StartPick(kind, function(path)
            box:SetText(path)
            save(path)
            ns.print(string.format(BIT.L("Picked %s."), path))
        end)
    end)
    if pick then
        pick:SetPoint("LEFT", box, "RIGHT", 6, 0)
        box:SetWidth(row.layout.control - pick:GetWidth() - 6)
    end
    function row:Refresh()
        if not box:HasFocus() then box:SetText(Frames.Get(key)) end
        self:ApplyEnabled(box)
    end
    return row
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function selectTab(tab)
    closeMenu()
    activeTab = tab
    for _, other in ipairs(tabs) do
        local selected = other == tab
        other.content:SetShown(selected)
        BIT.UI.TabSelected(other.button, selected)
        if other.footer then other.footer:SetShown(selected) end
    end
end

-- A tab whose methods add rows top to bottom and remember the setting keys, for "Reset this tab".
local function addTab(name)
    local area = window.settingsArea
    local tab = { keys = {}, y = 0 }
    tab.content = CreateFrame("Frame", nil, area)
    tab.content:SetPoint("TOPLEFT", area, "TOPLEFT", 8, -40 - TAB_HEIGHT)
    tab.content:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -8, 40)
    tab.content:Hide()

    local button = CreateFrame("Button", nil, area, "PanelTopTabButtonTemplate")
    button:SetText(BIT.L(name))
    button.text = button:GetFontString()
    button:SetSize(BIT.UI.TabWidth(button.text), TAB_HEIGHT)
    button.text:SetPoint("CENTER")
    BIT.UI.SkinTabButton(button, button.text)
    local previous = tabs[#tabs]
    -- Native tabs grow to fit their end caps on show; keep three per row.
    if previous and #tabs % 3 ~= 0 then
        button:SetPoint("LEFT", previous.button, "RIGHT", BIT.UI.TAB_GAP, 0)
    else
        button:SetPoint("TOPLEFT", area, "TOPLEFT", 8, -8 - math.floor(#tabs / 3) * TAB_HEIGHT)
    end
    button:SetScript("OnClick", function() selectTab(tab) end)
    tab.button = button

    local function place(row, key)
        row:SetPoint("TOPLEFT", tab.content, "TOPLEFT", 0, -tab.y)
        tab.y = tab.y + (row.standard and row:GetHeight() or ROW_HEIGHT)
        if key then table.insert(tab.keys, key) end
        return row
    end
    function tab:checkbox(key, ...) return place(checkbox(self.content, key, ...), key) end
    function tab:slider(key, ...) return place(slider(self.content, key, ...), key) end
    function tab:choice(key, ...) return place(choice(self.content, key, ...), key) end
    function tab:action(...) return place(actionRow(self.content, ...)) end
    function tab:frame(key, ...) return place(frameRow(self.content, key, ...)) end
    function tab:gap() self.y = self.y + 8 end

    table.insert(tabs, tab)
    return tab
end

local function resetTab(tab)
    for _, key in ipairs(tab.keys) do db()[key] = ns.DEFAULTS[key] end
    changed()
end

local function copyMarkerStyleToPlates()
    local settings = db()
    settings.plateFillTexture, settings.plateFillColor, settings.plateFillOpacity =
        settings.fillTexture, settings.fillColor, settings.fillOpacity
    settings.plateDotColors, settings.plateIcon = settings.dotColors, settings.skullIcon
    settings.plateOutlineStyle, settings.plateDashLength = settings.outlineStyle, settings.dashLength
    settings.plateOutlineThickness = math.min(settings.outlineThickness, 3)
    settings.plateOutlineColor, settings.plateOutlineOpacity = settings.outlineColor, settings.outlineOpacity
end

local function applyPreset(preset)
    for key, value in pairs(preset.values) do db()[key] = value end
    copyMarkerStyleToPlates()
    changed()
    ns.print(string.format(BIT.L("%s preset applied to the target frame and nameplates."), BIT.L(preset.label)))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function isDashed(settings) return settings.outlineStyle == "dashed" end
local function hasOutline(settings) return settings.outlineStyle ~= "none" end
local function singleColor(settings) return settings.dotColors == "single" end
local function perDot(settings) return settings.dotColors ~= "single" end
local function showsLabel(settings) return settings.showLabel end

local function buildTabs()
    local lists = ns.lists
    lists.fills.kind = "texture" -- the shared drop-down merges the whole catalog into it

    local icon = addTab("Kill icon")
    icon:checkbox("showSkull", "Show kill icon",
        { tooltip = "Shows an icon at the chosen position when your DoTs on the target will kill it." })
    icon:choice("skullIcon", "Kill icon", lists.icons)
    icon:slider("skullSize", "Icon size", 20, 128, 2)
    icon:checkbox("swingKill", "Count one weapon hit", { tooltip = "A weapon icon shows when your DoTs plus one "
        .. "average hit of your best weapon attack (melee swing, wand or ranged shot) would kill; the kill icon "
        .. "itself still means the DoTs alone are enough. The hit is "
        .. "the character sheet's average: armor, misses and crits are not counted, and the Kill margin applies. "
        .. "The marker itself still shows only the DoTs." })
    icon:slider("killMargin", "Kill margin", 50, 100, 5, { suffix = "%", tooltip = "The icon shows only when this "
        .. "share of the estimated DoT damage is enough to kill. Lower it if mobs that heal or regenerate survive the "
        .. "icon; 100% compares the full estimate. The marker always shows the full estimate." })
    icon:choice("skullPosition", "Icon position", {
        { id = "portrait", label = "Portrait" },
        { id = "left", label = "Left of the health bar" },
        { id = "right", label = "Right of the health bar" },
        { id = "above", label = "Above the health bar" },
        { id = "below", label = "Below the health bar" },
    })
    icon:checkbox("skullPulse", "Pulse", { tooltip = "Gently pulses the icon while it's showing." })
    icon:slider("skullOffsetX", "Icon horizontal offset", -60, 60, 1,
        { tooltip = "Pixels right (+) or left (-) of the chosen position." })
    icon:slider("skullOffsetY", "Icon vertical offset", -60, 60, 1,
        { tooltip = "Pixels up (+) or down (-) from the chosen position." })

    local marker = addTab("Marker")
    marker:checkbox("showMarkers", "Show damage marker", { tooltip = "Marks the damage your DoTs still have to "
        .. "deal on the target's health bar. If the health ends inside it, the target dies." })
    marker:checkbox("targetMarkers", "Show on target frame", { enabledIf = function(s) return s.showMarkers end,
        tooltip = "Keep this on to show the marker on your screen's target health bar. Plater changes nameplates, "
        .. "not that frame; if you use a separate unit frame addon, set its bar under Behavior > Target health bar. "
        .. "Turn off to keep the marker on nameplates and the focus frame only. On Retail this also hides the rogue's "
        .. "aura icons above the target bar. The kill icon has its own switch in the Kill icon tab." })
    marker:choice("dotColors", "DoT colors", lists.dotColors, { tooltip = "One color, or one segment per DoT "
        .. "with green poisons, purple curses/shadow damage and red bleeds. Rainbow gives each spell a separate color." })
    marker:choice("fillTexture", "Fill style", lists.fills)
    marker:choice("fillColor", "Fill color", lists.colors, { enabledIf = singleColor,
        tooltip = "Used when DoT colors is set to one color." })
    marker:slider("fillOpacity", "Fill opacity", 0, 100, 5, { suffix = "%" })
    marker:choice("fillDirection", "Fill direction", lists.plateFillDirections, { tooltip = "Which end of the "
        .. "target health bar the marker starts from. Follow health bar turns it around on a mirrored bar that "
        .. "drains the other way; choose Right to left if your unit frame addon is not recognized." })
    marker:checkbox("segmentDividers", "Dividers between DoTs", { enabledIf = perDot })
    marker:gap()
    marker:choice("outlineStyle", "Outline", lists.outlines)
    marker:choice("dashLength", "Dash length", lists.dashLengths, { enabledIf = isDashed })
    marker:slider("outlineThickness", "Outline thickness", 1, 8, 1, { enabledIf = hasOutline })
    marker:choice("outlineColor", "Outline color", lists.colors, { enabledIf = hasOutline })
    marker:slider("outlineOpacity", "Outline opacity", 10, 100, 5, { suffix = "%", enabledIf = hasOutline })

    local effects = addTab("Effects")
    effects:checkbox("smoothMotion", "Smooth motion",
        { tooltip = "The marker grows in when it appears and glides to new values instead of jumping." })
    effects:checkbox("flashOnApply", "Flash on new DoT")
    effects:checkbox("showSpark", "Spark", { tooltip = "A bright flare on the marker's edge when a DoT lands." })
    effects:checkbox("pulseOutline", "Pulse outline", { enabledIf = hasOutline })
    effects:gap()
    effects:checkbox("showGlow", "Glow", { enabledIf = hasOutline, tooltip = "Soft halo in the outline color." })
    effects:slider("glowSize", "Glow size", 2, 16, 1,
        { enabledIf = function(s) return hasOutline(s) and s.showGlow end })
    effects:checkbox("showShine", "Shine sweep")
    effects:slider("shineInterval", "Shine every", 2, 10, 1,
        { suffix = "s", enabledIf = function(s) return s.showShine end })
    effects:checkbox("scrollStripes", "Scroll stripes", { tooltip = "Animates the diagonal stripes fill.",
        enabledIf = function(s) return s.fillTexture == "stripes" and singleColor(s) end })

    local text = addTab("Text")
    text:checkbox("showLabel", "Show damage text",
        { tooltip = "Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)." })
    text:choice("labelPosition", "Text position", lists.labelPositions, { enabledIf = showsLabel })
    text:slider("labelSize", "Text size", 8, 20, 1, { enabledIf = showsLabel })
    text:choice("labelColor", "Text color", lists.colors, { enabledIf = showsLabel })

    -- Presets match both bars; these controls allow a separate nameplate look afterwards.
    local platesOn = function(s) return s.nameplateMode ~= "off" end
    local plateIcon = function(s) return s.nameplateMode == "markerIcon" end
    local plateSingle = function(s) return platesOn(s) and s.plateDotColors == "single" end
    local plateOutline = function(s) return platesOn(s) and s.plateOutlineStyle ~= "none" end
    local plates = addTab("Nameplates")
    plates:choice("nameplateMode", "Show on nameplates", lists.nameplateModes, { tooltip = "Draws a marker "
        .. "(and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below." })
    plates:choice("focusMode", "Show on focus frame", lists.nameplateModes, { tooltip = "Draws the same marker "
        .. "(and optionally the kill icon) on your focus frame's health bar for your DoTs on the focused enemy, "
        .. "in the nameplate look below." })
    plates:choice("plateIcon", "Kill icon", lists.icons, { enabledIf = plateIcon })
    plates:slider("nameplateIconSize", "Kill icon size", 12, 128, 1, { enabledIf = plateIcon })
    plates:choice("nameplateIconPosition", "Kill icon position", lists.nameplateIconPositions,
        { enabledIf = plateIcon })
    plates:slider("plateIconOffsetX", "Icon horizontal offset", -40, 40, 1,
        { enabledIf = plateIcon, tooltip = "Pixels right (+) or left (-) of the chosen position." })
    plates:slider("plateIconOffsetY", "Icon vertical offset", -40, 40, 1,
        { enabledIf = plateIcon, tooltip = "Pixels up (+) or down (-) from the chosen position." })
    plates:gap()
    plates:choice("plateDotColors", "DoT colors", lists.dotColors, { enabledIf = platesOn,
        tooltip = "By effect type: green poisons, purple curses/shadow damage and red bleeds. Rainbow: a separate color per spell." })
    plates:choice("plateFillTexture", "Fill style", lists.fills, { enabledIf = platesOn })
    plates:choice("plateFillDirection", "Fill direction", lists.plateFillDirections)
    plates:choice("plateFillColor", "Fill color", lists.colors, { enabledIf = plateSingle })
    plates:slider("plateFillOpacity", "Fill opacity", 0, 100, 5, { suffix = "%", enabledIf = platesOn })
    plates:choice("plateOutlineStyle", "Outline", lists.outlines, { enabledIf = platesOn })
    plates:choice("plateDashLength", "Dash length", lists.dashLengths,
        { enabledIf = function(s) return platesOn(s) and s.plateOutlineStyle == "dashed" end })
    plates:slider("plateOutlineThickness", "Outline thickness", 1, 3, 1, { enabledIf = plateOutline })
    plates:choice("plateOutlineColor", "Outline color", lists.colors, { enabledIf = plateOutline })
    plates:slider("plateOutlineOpacity", "Outline opacity", 10, 100, 5, { suffix = "%", enabledIf = plateOutline })
    plates.footer = pushButton(window.settingsArea, "Copy from Marker tab", 160, function()
        copyMarkerStyleToPlates()
        changed()
    end)
    plates.footer:SetPoint("BOTTOMLEFT", 10, 10)
    plates.footer:Hide()

    local behavior = addTab("Behavior")
    if not ns.Retail then
        behavior:choice("waitFirstTick", "Wait for first tick", lists.waitModes, { tooltip = "Whether a new DoT "
            .. "counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points "
            .. "and spells the addon hasn't seen tick yet." })
    end
    behavior:checkbox("refreshCue", "Show refresh marks",
        { tooltip = ns.Retail and "A gold edge when the estimated time left is within the 30% Pandemic refresh window."
            or "A gold edge on that DoT's segment while the time left is inside the refresh window: "
            .. "one tick, three seconds, or a quarter of the duration, whichever is longer. "
            .. "The damage number stays off unless you turn it on." })
    if not ns.Retail then
        behavior:checkbox("procDots", "Ignite, Deep Wounds, traps", { tooltip = "Mages and warriors: a critical hit lights "
            .. "Ignite (a share of the fire crit over 4 s) or Deep Wounds (a share of your weapon damage over 12 s), "
            .. "with no cast to say so. Assumes you have the talent (when the talent tree can be read and shows no "
            .. "points, nothing is drawn). A crit counts as yours when you cast at that mob just before, or, for "
            .. "Deep Wounds, swing at it while alone; the first tick confirms it. Traps (Immolation Trap) are "
            .. "tracked as well." })
        behavior:checkbox("deathMark", "Death Mark (experimental)", { tooltip = "Rogues: shows what Death Mark has "
            .. "stored so far as one more segment, until it goes off 6 s after the finisher, never above the cap in its "
            .. "description. Garrote and Rupture ticks count twice. Experimental, off by default: the game doesn't say "
            .. "who hit the marked mob, so every hit on it counts as yours. In a party or raid the others' damage is "
            .. "counted too and the estimate runs high. Not tested in game." })
    end
    behavior:checkbox("targetOverMouseover", "Target beats mouseover", { tooltip =
        "For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon "
        .. "can't tell which of the two your spell goes to and hides the estimate. With this on, your target "
        .. "(or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, "
        .. "the estimate could then show on the wrong mob.)" })
    behavior:checkbox("estimateDuringCast", "Estimate during casting", { tooltip = "Shows a DoT with a cast time "
        .. "while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or "
        .. "failed cast removes it." })
    behavior:checkbox("debug", "Echo trace log to chat",
        { tooltip = ns.Retail and "Prints each DoT cast and damage estimate to chat."
            or "Prints each DoT cast, matched tick and estimate to chat." })
    if ns.Retail then
        behavior:action("Retail damage estimate", "Info", function()
            ns.print(BIT.L("Rogue bleed and poison icons use WoW's aura timers. DoT damage is estimated from your casts and spell descriptions; dispels, immunities, procs and damage modifiers may change it."))
        end, { tooltip = "The skull means estimated damage exceeds health. It is a prediction, not a confirmed kill." })
    else
        behavior:action("Learned tick sizes", "View", function() ns.toggleTickViewer() end, { tooltip = "What each of "
            .. "your DoTs really ticks for, learned from earlier casts and used instead of the tooltip's number. "
            .. "You can also type /dotinfo ticks." })
        behavior:action("Forget learned sizes", "Reset", function() ns.resetLearnedTicks() end,
            { tooltip = "Forget the tick sizes learned from earlier casts." })
    end
    -- Another addon's unit frames (Core/Frames.lua); shared with ShieldsInfo and HealPrediction.
    behavior:gap()
    behavior:frame("target", "Target health bar", "bar", { tooltip = "For unit frame addons that replace "
        .. "Blizzard's target frame (ElvUI, Shadowed Unit Frames, ...). Target something, click Pick, then click "
        .. "its health bar; or type the frame's name (/fstack shows it), like ElvUF_Target.Health. For a bar that "
        .. "drains the other way, see Fill direction on the Marker tab. Empty: Blizzard's, or EllesmereUI's or "
        .. "X-Perl's when it shows its own. Shared with ShieldsInfo "
        .. "and HealPrediction. Plater replaces nameplates, not the screen target frame; its nameplate marker is "
        .. "handled separately." })
    behavior:frame("icon", "Kill icon spot", "anchor", { tooltip = "Where the kill icon is centered (e.g. the "
        .. "custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's; with a custom health bar and no spot "
        .. "the icon sits on that bar. Fine-tune with the offsets on the Kill icon tab." })
    behavior:frame("focus", "Focus health bar", "bar", { tooltip = "The same for the focus frame. Empty: "
        .. "Blizzard's, or EllesmereUI's when it shows its own." })
    behavior:frame("plate", "Nameplate health bar", "bar", { noPick = true, tooltip = "Most nameplate addons' "
        .. "bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker does not show on "
        .. "yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /dotinfo plates "
        .. "logs what each plate uses. Empty: automatic." })
end

local function buildPreview(pane)
    -- y in px from the pane's top (pane: PREVIEW_WIDTH x ~486); every block on the same 12 px side margins.
    local SIDE = 12
    local CARD_WIDTH = PREVIEW_WIDTH - 2 * SIDE -- 266
    local RULE = BIT.UI.COLOR.divider

    -- Forever ships its own bronze ("-c60") versions of the modern HUD art: those first, else the plain atlas
    -- (Retail). false when neither exists, so the caller keeps a plain fallback.
    local function setAtlas(texture, name)
        if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
        for _, candidate in ipairs({ name .. "-c60", name }) do
            if C_Texture.GetAtlasInfo(candidate) then
                texture:SetAtlas(candidate)
                return true
            end
        end
        return false
    end
    local function fontOr(name, fallback) return _G[name] and name or fallback end
    -- Vertical gradient (bottom colour, top colour); a flat colour where the client has no gradient API.
    local function gradient(texture, bottom, top)
        texture:SetTexture(WHITE)
        if CreateColor and pcall(texture.SetGradient, texture, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]), CreateColor(top[1], top[2], top[3], top[4])) then
            return
        end
        texture:SetVertexColor(bottom[1], bottom[2], bottom[3], (bottom[4] + top[4]) / 2)
    end
    -- Section header: small gold caps and a hairline to the right margin.
    local function header(text, anchor, gap)
        local label = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
        label:SetText(BIT.L(text))
        label:SetTextColor(0.85, 0.7, 0.3)
        local rule = pane:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(RULE[1], RULE[2], RULE[3], RULE[4])
        rule:SetHeight(1)
        rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
        rule:SetPoint("RIGHT", pane, "RIGHT", -SIDE, 0)
        return label
    end

    -- Title row, level with the tab row on the right (its divider is also 34 px down).
    local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", SIDE, -12)
    title:SetText(BIT.L("Live preview"))
    local titleRule = pane:CreateTexture(nil, "ARTWORK")
    titleRule:SetColorTexture(RULE[1], RULE[2], RULE[3], RULE[4])
    titleRule:SetHeight(1)
    titleRule:SetPoint("TOPLEFT", 8, -34)
    titleRule:SetPoint("TOPRIGHT", -8, -34)

    -- Scene (44..234): a patch of dusky world behind the mock frames, so they read as the game's own HUD.
    local scene = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    scene:SetSize(CARD_WIDTH, 190)
    scene:SetPoint("TOP", pane, "TOP", 0, -44)
    scene:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    scene:SetBackdropBorderColor(0, 0, 0, 1)
    local ground = scene:CreateTexture(nil, "BACKGROUND", nil, -8)
    ground:SetPoint("TOPLEFT", 1, -1)
    ground:SetPoint("BOTTOMRIGHT", -1, 1)
    ground:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    ground:SetTexCoord(0, 0.26, 0, 0.18) -- about 1:1 texels on a 266 x 190 patch
    ground:SetVertexColor(0.75, 0.8, 0.75)
    local sky = scene:CreateTexture(nil, "BACKGROUND", nil, -7)
    sky:SetAllPoints(ground)
    gradient(sky, { 0.055, 0.08, 0.04, 0.25 }, { 0.07, 0.1, 0.15, 0.6 })
    local topShade = scene:CreateTexture(nil, "BACKGROUND", nil, -6)
    topShade:SetPoint("TOPLEFT", ground, "TOPLEFT")
    topShade:SetPoint("TOPRIGHT", ground, "TOPRIGHT")
    topShade:SetHeight(26)
    gradient(topShade, { 0, 0, 0, 0 }, { 0, 0, 0, 0.6 })
    local bottomShade = scene:CreateTexture(nil, "BACKGROUND", nil, -6)
    bottomShade:SetPoint("BOTTOMLEFT", ground, "BOTTOMLEFT")
    bottomShade:SetPoint("BOTTOMRIGHT", ground, "BOTTOMRIGHT")
    bottomShade:SetHeight(30)
    gradient(bottomShade, { 0, 0, 0, 0.65 }, { 0, 0, 0, 0 })

    -- Mock target frame: Forever's own target frame (TargetFrameTemplate, 232 x 100) rebuilt from its atlases at
    -- Blizzard's offsets, so the marker and kill icon land where they will in combat.
    local mock = CreateFrame("Frame", nil, scene)
    mock:SetSize(232, 100)
    mock:SetPoint("TOP", scene, "TOP", 0, -4)

    local portrait = mock:CreateTexture(nil, "BACKGROUND", nil, 1)
    portrait:SetSize(58, 58)
    portrait:SetPoint("TOPRIGHT", mock, "TOPRIGHT", -26, -19)
    portrait:SetTexture("Interface\\Icons\\Achievement_Reputation_MurlocOracle")
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- the icon's own border would show at the circle's edge
    local mask = mock:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)

    local frameArt = mock:CreateTexture(nil, "BACKGROUND", nil, 2)
    frameArt:SetSize(192, 67)
    frameArt:SetPoint("TOPLEFT", mock, "TOPLEFT", 20, -16)
    local hasFrameArt = setAtlas(frameArt, "UI-HUD-UnitFrame-Target-PortraitOn")
    if not hasFrameArt then
        frameArt:ClearAllPoints()
        frameArt:SetPoint("TOPLEFT", mock, "TOPLEFT", 18, -22)
        frameArt:SetSize(134, 42)
        frameArt:SetColorTexture(0, 0, 0, 0.55)
    end

    local nameBand = mock:CreateTexture(nil, "BORDER")
    nameBand:SetSize(135, 18)
    nameBand:SetPoint("TOPLEFT", mock, "TOPLEFT", 22, -25)
    if setAtlas(nameBand, "UI-HUD-UnitFrame-Target-PortraitOn-Type") then
        nameBand:SetVertexColor(1, 0, 0) -- hostile, as UnitSelectionColor colours it
    else
        nameBand:Hide()
    end

    local name = mock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetSize(117, 12)
    name:SetPoint("TOPLEFT", mock, "TOPLEFT", 24, -26)
    name:SetJustifyH("LEFT")
    name:SetText("Murloc Raider")

    local levelCircle = mock:CreateTexture(nil, "OVERLAY")
    levelCircle:SetSize(39, 39)
    levelCircle:SetPoint("BOTTOMRIGHT", mock, "BOTTOMRIGHT", -13, 7)
    local level = mock:CreateFontString(nil, "OVERLAY", fontOr("WhiteLargeNumberFont", "GameFontNormal"))
    level:SetDrawLayer("OVERLAY", 2)
    level:SetPoint("CENTER", levelCircle, "CENTER", 0, -0.5)
    level:SetText("12")
    level:SetTextColor(1, 0.82, 0) -- same-level ("fair") difficulty colour
    if not setAtlas(levelCircle, "UI-HUD-UnitFrame-SmallCircle") then
        levelCircle:Hide()
        level:Hide()
    end

    -- Health bar: 126 x 20 in the frame art's upper slot (the lower, power slot stays empty: a murloc raider
    -- has no mana). The marker is SetAllPoints'd onto this bar.
    local healthBar = CreateFrame("StatusBar", nil, mock)
    healthBar:SetSize(126, 20)
    healthBar:SetPoint("TOPLEFT", mock, "TOPLEFT", 22, -39)
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    if setAtlas(healthBar:GetStatusBarTexture(), "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health") then
        healthBar:SetStatusBarColor(1, 1, 1)
    else
        healthBar:SetStatusBarColor(0.1, 0.8, 0.1)
    end
    if not hasFrameArt then
        local healthBack = healthBar:CreateTexture(nil, "BACKGROUND")
        healthBack:SetAllPoints()
        healthBack:SetColorTexture(0.25, 0.08, 0.08, 1)
    end
    -- The numbers the game's own frame prints on the bar: percent on the left, health on the right.
    local barText = fontOr("TextStatusBarText", "GameFontHighlightSmall")
    window.healthPercent = healthBar:CreateFontString(nil, "OVERLAY", barText)
    window.healthPercent:SetPoint("LEFT", healthBar, "LEFT", 3, 0)
    window.healthValue = healthBar:CreateFontString(nil, "OVERLAY", barText)
    window.healthValue:SetPoint("RIGHT", healthBar, "RIGHT", -3, 0)

    window.healthBar = healthBar
    window.host = { healthBar = healthBar, portrait = portrait, layerFrame = window }
    window.mock = mock

    -- Mock enemy nameplate: Forever's default ("Thin") plate, 190 wide: a 133 x 13 bar, the level badge right
    -- of it, the name centred above. Drawn on by the real nameplate code (Nameplates.lua).
    local mockPlate = CreateFrame("Frame", nil, scene)
    mockPlate:SetSize(190, 36)
    mockPlate:SetPoint("BOTTOM", scene, "BOTTOM", 0, 22)
    local plateBar = CreateFrame("StatusBar", nil, mockPlate)
    plateBar:SetSize(133, 13)
    plateBar:SetPoint("BOTTOMLEFT", mockPlate, "BOTTOMLEFT", 12, 6)
    plateBar:SetMinMaxValues(0, 100)
    plateBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    if setAtlas(plateBar:GetStatusBarTexture(), "UI-HUD-CoolDownManager-Bar") then
        plateBar:SetStatusBarColor(1, 0, 0) -- hostile
    else
        plateBar:SetStatusBarColor(0.85, 0.1, 0.1)
    end
    local plateBack = mockPlate:CreateTexture(nil, "BACKGROUND")
    plateBack:SetPoint("TOPLEFT", plateBar, "TOPLEFT", -2, 3)
    plateBack:SetPoint("BOTTOMRIGHT", plateBar, "BOTTOMRIGHT", 6, -6)
    if not setAtlas(plateBack, "UI-HUD-CoolDownManager-Bar-BG") then
        plateBack:ClearAllPoints()
        plateBack:SetAllPoints(plateBar)
        plateBack:SetColorTexture(0.1, 0.02, 0.02, 1)
    end
    -- It is your target's plate: the target border (Forever: yellow art, vertex white).
    local plateSelected = plateBar:CreateTexture(nil, "OVERLAY")
    plateSelected:SetPoint("TOPLEFT", plateBack, "TOPLEFT", -3, 2)
    plateSelected:SetPoint("BOTTOMRIGHT", plateBack, "BOTTOMRIGHT", 0, 2)
    if setAtlas(plateSelected, "UI-HUD-CoolDownManager-Selected-yellow") then
        plateSelected:SetVertexColor(1, 1, 1, 0.9)
    else
        plateSelected:Hide()
    end
    local plateLevel = mockPlate:CreateTexture(nil, "ARTWORK")
    plateLevel:SetSize(28, 16)
    plateLevel:SetPoint("LEFT", plateBar, "RIGHT", 5, 0)
    local plateLevelText = mockPlate:CreateFontString(nil, "OVERLAY", fontOr("SystemFont_NamePlateLevel", "GameFontNormalSmall"))
    plateLevelText:SetPoint("CENTER", plateLevel, "CENTER")
    plateLevelText:SetText("12")
    plateLevelText:SetTextColor(1, 0.82, 0)
    if not setAtlas(plateLevel, "UI-HUD-Nameplates-LevelIndicator") then
        plateLevel:Hide()
        plateLevelText:Hide()
    end
    local plateName = mockPlate:CreateFontString(nil, "OVERLAY",
        fontOr("SystemFont_NamePlate_Outlined", "GameFontHighlightSmallOutline"))
    plateName:SetPoint("BOTTOMLEFT", plateBar, "TOPLEFT", 0, 6) -- clear of the target border, which rises 5 above the bar
    plateName:SetPoint("RIGHT", plateLevel, "RIGHT")
    plateName:SetJustifyH("CENTER")
    plateName:SetText("Murloc Raider")
    plateName:SetTextColor(1, 0.13, 0.13) -- hostile
    window.mockPlate = mockPlate
    window.plateHealthBar = plateBar
    window.plateHost = { plate = mockPlate, healthBar = plateBar }

    -- Shown over the mock frames while combat has the display back on the real target. On its own layer above
    -- the scene: a font string on the pane would draw under it.
    local noteLayer = CreateFrame("Frame", nil, scene)
    noteLayer:SetAllPoints(scene)
    noteLayer:SetFrameLevel(mock:GetFrameLevel() + 10)
    window.combatNote = noteLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.combatNote:SetPoint("CENTER", scene, "CENTER")
    window.combatNote:SetWidth(CARD_WIDTH - 24)
    window.combatNote:SetText(BIT.L("In combat: the marker and kill icon are showing on your target. "
        .. "The preview resumes after combat."))
    window.combatNote:Hide()

    -- Verdict badge (242..272), right under the scene it describes: accent stripe, icon, verdict, numbers.
    local badge = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    badge:SetSize(CARD_WIDTH, 30)
    badge:SetPoint("TOP", scene, "BOTTOM", 0, -8)
    badge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    badge.accent = badge:CreateTexture(nil, "ARTWORK")
    badge.accent:SetPoint("TOPLEFT", 1, -1)
    badge.accent:SetPoint("BOTTOMLEFT", 1, 1)
    badge.accent:SetWidth(3)
    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    badge.icon:SetSize(18, 18)
    badge.icon:SetPoint("LEFT", badge, "LEFT", 12, 0)
    window.statusDetail = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.statusDetail:SetPoint("RIGHT", badge, "RIGHT", -10, 0)
    window.statusDetail:SetJustifyH("RIGHT")
    window.statusDetail:SetTextColor(0.75, 0.75, 0.75)
    window.status = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.status:SetPoint("LEFT", badge.icon, "RIGHT", 8, 0)
    window.status:SetPoint("RIGHT", window.statusDetail, "LEFT", -8, 0)
    window.status:SetJustifyH("LEFT")
    window.status:SetWordWrap(false)
    window.statusBadge = badge

    -- Try it: the preview's own numbers (not settings).
    local tryIt = header("TRY IT", badge, 16)
    local health = sliderRow(pane, "Target health", 0, 100, 1,
        function() return preview.health end,
        function(value)
            stopSimulation()
            preview.health = value
            updatePreview()
        end, { layout = PREVIEW_LAYOUT, suffix = "%" })
    health:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -6, -6) -- rows start 6 px in, so their labels sit on the margin
    local damage = sliderRow(pane, "DoT damage", 0, 100, 1,
        function() return math.floor(previewTotal() + 0.5) end,
        function(value)
            stopSimulation()
            setPreviewDamage(value)
            updatePreview()
        end, { layout = PREVIEW_LAYOUT, suffix = "%",
            tooltip = "Remaining damage of two sample DoTs, in % of the target's max health." })
    damage:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, 0)

    window.simulateButton = pushButton(pane, "Simulate fight", 162, function()
        if simulation then stopSimulation() else startSimulation() end
    end)
    window.simulateButton:SetPoint("TOPLEFT", damage, "BOTTOMLEFT", 6, -10)
    window.flashButton = pushButton(pane, "Flash", 96, function() ns.playFlash() end)
    window.flashButton:SetPoint("LEFT", window.simulateButton, "RIGHT", 8, 0)

    local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", SIDE, 12)
    hint:SetWidth(CARD_WIDTH)
    hint:SetJustifyH("LEFT")
    hint:SetText(BIT.L("While this window is open, the marker and kill icon are drawn here instead of on your target."))
    local hintRule = pane:CreateTexture(nil, "ARTWORK")
    hintRule:SetColorTexture(RULE[1], RULE[2], RULE[3], RULE[4])
    hintRule:SetHeight(1)
    hintRule:SetPoint("BOTTOMLEFT", hint, "TOPLEFT", 0, 8)
    hintRule:SetPoint("RIGHT", pane, "RIGHT", -SIDE, 0)
end

-- The presets, the preview and the settings, in window: the addon's own window, below its title bar
-- with the presets beside anchor (its close button), or inside Ready2QuestCombat the tab it is built into.
local function buildContent(top, anchor)
    -- Presets, right-aligned in the title bar: the shared "Look presets" button.
    local presetLabel = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    local presetButton = BIT.Looks.PresetButton(window, PRESETS, applyPreset)
    presetButton:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
    presetLabel:SetPoint("RIGHT", presetButton, "LEFT", -8, 0)
    presetLabel:SetText(BIT.L("Both bars"))

    local pane = CreateFrame("Frame", nil, window, "BackdropTemplate")
    pane:SetPoint("TOPLEFT", 10, -top)
    pane:SetPoint("BOTTOMLEFT", 10, 10)
    pane:SetWidth(PREVIEW_WIDTH)
    setBackdrop(pane, 0.09)
    buildPreview(pane)

    local area = CreateFrame("Frame", nil, window, "BackdropTemplate")
    area:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
    area:SetPoint("BOTTOMRIGHT", -10, 10)
    setBackdrop(area, 0.09)
    window.settingsArea = area

    local divider = area:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(BIT.UI.COLOR.divider))
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 8, -34 - TAB_HEIGHT)
    divider:SetPoint("TOPRIGHT", -8, -34 - TAB_HEIGHT)

    buildTabs()
    local reset = pushButton(area, "Reset this tab", 120, function() resetTab(activeTab) end)
    reset:SetPoint("BOTTOMRIGHT", -10, 10)

    window:SetScript("OnShow", function()
        ns.setPreviewState(preview)
        window.previewPaused = nil
        syncDisplayHost()
        refreshControls()
        updatePreview()
    end)
    window:SetScript("OnHide", function()
        stopSimulation()
        closeMenu()
        ns.setPreviewState(nil)
        ns.setDisplayHost(nil)
        ns.setPlatePreview(nil)
    end)
    -- Combat hands the display back to the real target, and after combat back to the preview.
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:RegisterEvent("PLAYER_REGEN_ENABLED")
    window:SetScript("OnEvent", function() syncDisplayHost() end)
    selectTab(tabs[1])
end

local function createWindow()
    window = CreateFrame("Frame", "Ready2QuestCombat_DoTInfoOptions", UIParent, "BackdropTemplate")
    window:Hide() -- new frames start shown; ns.openOptions shows it (running OnShow)
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    setBackdrop(window, 0.06, 0.97)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "Ready2QuestCombat_DoTInfoOptions") end -- Escape closes it

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -18)
    title:SetText("DoTInfo")
    title:SetTextColor(BIT.UI.COLOR.heading[1], BIT.UI.COLOR.heading[2], BIT.UI.COLOR.heading[3])

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -12)

    buildContent(HEADER_HEIGHT, close)
end

function ns.openOptions()
    if not ns.db then return end
    if BIT.OpenSettings then BIT.OpenSettings("DoTInfo") return end
    if not window then createWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

-- Options > AddOns > DoTInfo: a short page with a button that opens the window.
function ns.registerOptions()
    local function openSettings()
        if not (window and window:IsShown()) then ns.openOptions() end
    end
    if type(BIT.UI.RegisterSettingsLauncher) == "function" and BIT.UI.RegisterSettingsLauncher("DoTInfo",
        BIT.L("Open the options window with a live preview. You can also type /dotinfo."), openSettings) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DoTInfo")
    title:SetTextColor(BIT.UI.COLOR.heading[1], BIT.UI.COLOR.heading[2], BIT.UI.COLOR.heading[3])
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetText(BIT.L("Settings have their own window with a live preview. You can also type /dotinfo."))
    local open = pushButton(panel, "Open settings", 180, openSettings)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "DoTInfo")
    Settings.RegisterAddOnCategory(category)
end

-- Inside Ready2QuestCombat: the window's content in its tab, with the presets at the tab's top right.
-- BIT Minimal OFF-scene sample: a static mock bar with a fixed tick label, never
-- live ticks and never real nameplates.
local function buildDoTPreview(parent)
  local scene = CreateFrame("Frame", nil, parent)
  scene:SetSize(560, 120)
  scene.title = scene:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scene.title:SetPoint("TOPLEFT", 12, -4)
  scene.title:SetText(BIT.L("DoTInfo sample (not your bars)"))
  scene.bar = CreateFrame("StatusBar", nil, scene)
  scene.bar:SetSize(180, 20)
  scene.bar:SetPoint("TOPLEFT", 12, -30)
  scene.bar:SetStatusBarTexture(WHITE)
  scene.bar:SetStatusBarColor(0.65, 0.2, 0.85)
  scene.bar:SetMinMaxValues(0, 100)
  scene.bar:SetValue(60)
  local back = scene.bar:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.12, 0.04, 0.16, 1)
  scene.label = scene:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  scene.label:SetPoint("TOPLEFT", 12, -56)
  scene.label:SetText(BIT.L("450 over 3 ticks"))
  scene.label:SetHeight(14)
  return scene
end

local function renderDoTPreview(scene, style)
  BIT.Style.ApplyText(scene.title, style, "text")
  BIT.Style.ApplyText(scene.label, style, "text")
  -- Native-Y min/max reflow: bar height, label row and scene height derive
  -- from the shared font size; widths stay fixed (no scale capability).
  -- The window is never resized.
  local fontSize = style.fontSize or 12
  local barH = math.max(20, fontSize + 6)
  local barDepth = 4 + fontSize + 8
  local labDepth = barDepth + barH + 4
  scene.bar:ClearAllPoints()
  scene.bar:SetPoint("TOPLEFT", 12, -barDepth)
  scene.bar:SetSize(180, barH)
  scene.label:ClearAllPoints()
  scene.label:SetPoint("TOPLEFT", 12, -labDepth)
  scene:SetSize(560, labDepth + fontSize + 16)
end

if BIT.RegisterTab then
    BIT.RegisterTab("DoTInfo", {
        title = "DoTInfo",
        summary = "Marks on the target's health bar the damage your DoTs still have to deal, with a kill icon "
            .. "when they will finish it.",
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT - HEADER_HEIGHT + 44,
        build = function(parent)
            if window == parent then return end
            stopSimulation()
            closeMenu()
            if window then
                window:Hide()
                window:UnregisterAllEvents()
                window:SetScript("OnShow", nil)
                window:SetScript("OnHide", nil)
                window:SetScript("OnEvent", nil)
            end
            controls, tabs, activeTab = {}, {}, nil
            window = parent
            local anchor = CreateFrame("Frame", nil, parent)
            anchor:SetSize(1, 22)
            anchor:SetPoint("TOPRIGHT", -10, -8)
            buildContent(40, anchor)
        end,
        buildPreview = buildDoTPreview,
        previewRender = renderDoTPreview,
        capabilities = { roles = { "text" }, shapes = false,
            geometry = false, border = false, font = true, scale = false, opacity = true },
    })
    BIT.tabWords.dot, BIT.tabWords.did = "DoTInfo", "DoTInfo"
end
