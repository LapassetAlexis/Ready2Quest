-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: nameplates. Based on the standalone DoT addon's nameplate code
-- at e4faef4 by Joe Greive (MIT); it lives only here now and is edited directly.
-- The damage marker (and optionally the kill icon) on every enemy nameplate that has your
-- DoTs on it, using the per-mob tracking in Core.lua (ns.dotBreakdownForUnit). Same secret-value trick as
-- the target frame: StatusBars are fed the mob's hidden health and do the comparing.
--
-- Widgets are cached and parented to the Blizzard nameplate frame (which WoW recycles between mobs).
-- Bar dimensions are copied separately: parenting to the native StatusBar hid the overlay in-game.
-- They're lighter than the target marker: fill, per-DoT segments and a
-- thin outline in the Marker tab's style; presets match their fill and DoT colors to the target marker.
--
-- Also the probe (/dotinfo plates): what the addon can reach on nameplates, logged, with a test bar on each.

local ADDON_NAME, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Ready2QuestCombat's own namespace for the module, shared by its four files.
local ns = BIT.Module("DoTInfo")

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MAX_PLATES = 40
-- The 40 slots are polled on this beat so the marker follows DoT ticks and health.
-- A tick lands once a second or slower, and the death check hides within one beat
-- (L11-3): 5 Hz keeps that late by at most a fifth of a second and cuts the 40
-- UnitExists per beat -- 400/s at 10 Hz -- to 200/s.
local UPDATE_INTERVAL = 0.2
local MAX_SEGMENTS = 8 -- same per-DoT capacity as the target marker
local OUTLINE_THICKNESS = 1
local ICON_BAR_LENGTH = 10000 -- see the kill icon notes in Core.lua
local FALLBACK_LEVEL = 200    -- frame level when the plate's own level can't be read
local TEST_SECONDS = 8
local TEST_BAR_WIDTH, TEST_BAR_HEIGHT = 90, 6

ns.lists.nameplateModes = {
    { id = "off",        label = "Off" },
    { id = "marker",     label = "Marker only" },
    { id = "markerIcon", label = "Marker and kill icon" },
}
ns.lists.nameplateIconPositions = {
    { id = "right", label = "Right of the health bar" },
    { id = "left",  label = "Left of the health bar" },
    { id = "above", label = "Above the health bar" },
    { id = "below", label = "Below the health bar" },
}
ns.lists.plateFillDirections = {
    { id = "auto", label = "Follow health bar" },
    { id = "ltr", label = "Left to right" },
    { id = "rtl", label = "Right to left" },
}

local testBars = {}
local hideTestBarsAt = 0

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- "secret", "nil", "error: ...", or the value.
local function describe(ok, value)
    if not ok then return "error: " .. tostring(value) end
    if isSecret(value) then return "secret" end
    if value == nil then return "nil" end
    return tostring(value)
end

local function call(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    return describe(pcall(fn, ...))
end

-- Probe only: preserve each raw coordinate so hidden layout values never enter arithmetic.
local function geometry(region)
    if type(region) ~= "table" then return "missing" end
    local rect = "missing"
    if type(region.GetRect) == "function" then
        local ok, left, bottom, width, height = pcall(region.GetRect, region)
        if ok then
            rect = table.concat({ describe(true, left), describe(true, bottom),
                describe(true, width), describe(true, height) }, ",")
        else
            rect = describe(false, left)
        end
    end
    return "rect(" .. rect .. ") scale=" .. call(region.GetEffectiveScale, region)
        .. " local=" .. call(region.GetScale, region)
        .. " ignoreParent=" .. call(region.IsIgnoringParentScale, region)
        .. " visible=" .. call(region.IsVisible, region)
end

local findHealthBar = BIT.Plate.HealthBar

---------------------------------------------------------------------------
-- Nameplate display
---------------------------------------------------------------------------

local widgetsByPlate = {} -- Blizzard nameplate frame -> our widgets

local function coverSpan(texture, span)
    texture:SetPoint("TOPLEFT", span, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
end

local function invisibleBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    return bar
end

local function positiveGeometry(value)
    return not isSecret(value) and type(value) == "number" and value > 0 and value < math.huge
end

local function fitMarker(w)
    local bar = w.healthBar
    local ok, width, height = pcall(bar.GetSize, bar)
    local barOK, barScale = pcall(bar.GetEffectiveScale, bar)
    local ownOK, ownScale = pcall(w.marker.GetEffectiveScale, w.marker)
    if ok and barOK and ownOK and positiveGeometry(width) and positiveGeometry(height)
        and positiveGeometry(barScale) and positiveGeometry(ownScale) then
        -- the visible bar, where it is smaller than the HealthBar frame (Blizzard's Camelot frames; 0, 0 anywhere else)
        local top, bottom = 0, 0
        if BIT.Plate.BarInset then top, bottom = BIT.Plate.BarInset(bar) end
        local ratio = barScale / ownScale
        width, height = width * ratio, (height - top - bottom) * ratio
        local offset = -top * ratio
        if positiveGeometry(width) and positiveGeometry(height) then
            if w.geometryBar ~= bar or w.geometryWidth ~= width or w.geometryHeight ~= height or w.geometryOffset ~= offset then
                w.marker:ClearAllPoints()
                w.marker:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, offset)
                w.marker:SetSize(width, height)
                w.geometryBar, w.geometryWidth, w.geometryHeight, w.geometryOffset = bar, width, height, offset
            end
            return
        end
    end
    -- Hidden layout values stay in native anchors, never in arithmetic or a guessed size.
    w.geometryBar, w.geometryWidth, w.geometryHeight, w.geometryOffset = nil, nil, nil, nil
    w.marker:ClearAllPoints()
    w.marker:SetAllPoints(bar)
end

local function createWidgets(plate, healthBar)
    local host = BIT.Plate.WidgetHost(plate)
    local w = { healthBar = healthBar, host = host, markerHost = host, plate = plate }

    -- Marker: filled from the bar's left edge to the remaining DoT damage, on the mob's (secret) health scale.
    w.marker = invisibleBar(host)
    fitMarker(w)
    w.span = w.marker:GetStatusBarTexture()
    w.fill = w.marker:CreateTexture(nil, "ARTWORK")
    coverSpan(w.fill, w.span)

    -- Per-DoT segments: running-total bars, each segment between the previous bar's fill end and its own.
    w.segments = {}
    for i = 1, MAX_SEGMENTS do
        local bar = invisibleBar(w.marker)
        bar:SetAllPoints(w.marker)
        local fillEnd = bar:GetStatusBarTexture()
        local texture = w.marker:CreateTexture(nil, "ARTWORK", nil, 1)
        if i == 1 then
            texture:SetPoint("TOPLEFT", w.marker, "TOPLEFT")
        else
            texture:SetPoint("TOPLEFT", w.segments[i - 1].fillEnd, "TOPRIGHT")
        end
        texture:SetPoint("BOTTOMRIGHT", fillEnd, "BOTTOMRIGHT")
        local divider = w.marker:CreateTexture(nil, "OVERLAY", nil, 1)
        divider:SetColorTexture(0, 0, 0, 0.85)
        divider:SetWidth(1)
        divider:SetPoint("TOP", fillEnd, "TOPRIGHT")
        divider:SetPoint("BOTTOM", fillEnd, "BOTTOMRIGHT")
        divider:Hide()
        local refresh = w.marker:CreateTexture(nil, "OVERLAY", nil, 3)
        refresh:SetColorTexture(1, 0.82, 0.2, 1)
        refresh:SetWidth(3)
        refresh:SetPoint("TOP", fillEnd, "TOPRIGHT")
        refresh:SetPoint("BOTTOM", fillEnd, "BOTTOMRIGHT")
        refresh:Hide()
        w.segments[i] = { bar = bar, fillEnd = fillEnd, texture = texture, divider = divider, refresh = refresh }
    end
    w.refresh = w.marker:CreateTexture(nil, "OVERLAY", nil, 3)
    w.refresh:SetColorTexture(1, 0.82, 0.2, 1)
    w.refresh:SetWidth(3)
    w.refresh:SetPoint("TOP", w.span, "TOPRIGHT")
    w.refresh:SetPoint("BOTTOM", w.span, "BOTTOMRIGHT")
    w.refresh:Hide()

    w.edges = {}
    for _, points in ipairs({ { true, "TOPLEFT", "TOPRIGHT" }, { true, "BOTTOMLEFT", "BOTTOMRIGHT" },
        { false, "TOPLEFT", "BOTTOMLEFT" }, { false, "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = w.marker:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(points[2], w.span, points[2])
        edge:SetPoint(points[3], w.span, points[3])
        if points[1] then edge:SetHeight(OUTLINE_THICKNESS) else edge:SetWidth(OUTLINE_THICKNESS) end
        table.insert(w.edges, { texture = edge, horizontal = points[1] })
    end

    -- Kill icon: a clipped window; the icon rides the end of a very long bar with max = current health and
    -- value = remaining damage, so it only slides into the window when damage >= health.
    w.iconWindow = CreateFrame("Frame", nil, host)
    w.iconWindow:SetClipsChildren(true)
    w.iconBar = invisibleBar(w.iconWindow)
    w.iconBar:SetPoint("RIGHT", w.iconWindow, "RIGHT")
    w.icon = w.iconBar:CreateTexture(nil, "OVERLAY")
    w.icon:SetPoint("RIGHT", w.iconBar:GetStatusBarTexture(), "RIGHT")
    -- the weapon icon beside the skull's logic: lit by the DoTs plus one swing (SwingIcon.lua)
    w.swing = ns.SwingIcon and ns.SwingIcon.New(w.iconWindow, w.iconBar) or nil

    widgetsByPlate[plate] = w
    return w
end

-- Above the plate's health bar, in its strata. Done on every draw, not only when the widgets are made:
-- the client re-levels plates while they live (the target's, overlapping ones), and with some of
-- Blizzard's nameplate settings the bar then ended above a marker levelled once, covering it. Its level
-- can be secret in Forever; then a fixed high level.
local function keepAbove(w)
    local healthBar = w.healthBar
    local ok, level = pcall(healthBar.GetFrameLevel, healthBar)
    if not ok or isSecret(level) or type(level) ~= "number" then level = FALLBACK_LEVEL end
    local okStrata, strata = pcall(healthBar.GetFrameStrata, healthBar)
    if not okStrata or isSecret(strata) or type(strata) ~= "string" then strata = nil end
    if level == w.barLevel and strata == w.barStrata then return end
    w.barLevel, w.barStrata = level, strata
    if strata then
        w.marker:SetFrameStrata(strata)
        w.iconWindow:SetFrameStrata(strata)
    end
    -- The icon sits well above: plate decorations beside the bar (the level badge) must not cover it.
    w.marker:SetFrameLevel(level + 5)
    w.iconWindow:SetFrameLevel(level + 20)
    w.iconBar:SetFrameLevel(level + 21)
end

-- Nameplates have their own look (plate* settings), separate from the target marker: enemy plates are red.
local STYLE_KEYS = {
    "plateFillTexture", "plateFillColor", "plateFillOpacity", "plateDotColors", "plateOutlineStyle",
    "plateDashLength", "plateOutlineThickness", "plateOutlineColor", "plateOutlineOpacity", "plateIcon",
    "nameplateIconSize", "nameplateIconPosition", "plateIconOffsetX", "plateIconOffsetY", "plateFillDirection", "swingKill",
}

-- Pushes the look settings onto one plate's widgets when any of them changed since the last time.
local function applyStyle(w, db)
    local parts = {}
    for i, key in ipairs(STYLE_KEYS) do parts[i] = tostring(db[key]) end
    local reverse = db.plateFillDirection == "rtl"
    if db.plateFillDirection ~= "ltr" and db.plateFillDirection ~= "rtl"
        and type(w.healthBar.GetReverseFill) == "function" then
        local ok, value = pcall(w.healthBar.GetReverseFill, w.healthBar)
        reverse = ok and not isSecret(value) and value == true
    end
    if type(w.marker.SetReverseFill) ~= "function" then reverse = false end
    local signature = table.concat(parts, "|") .. "|" .. tostring(reverse)
    if signature == w.signature then return end
    w.signature = signature

    if type(w.marker.SetReverseFill) == "function" then w.marker:SetReverseFill(reverse) end
    local start, finish = reverse and "RIGHT" or "LEFT", reverse and "LEFT" or "RIGHT"
    for i, segment in ipairs(w.segments) do
        if type(segment.bar.SetReverseFill) == "function" then segment.bar:SetReverseFill(reverse) end
        segment.texture:ClearAllPoints()
        if i == 1 then
            segment.texture:SetPoint("TOP" .. start, w.marker, "TOP" .. start)
        else
            segment.texture:SetPoint("TOP" .. start, w.segments[i - 1].fillEnd, "TOP" .. finish)
        end
        segment.texture:SetPoint("BOTTOM" .. finish, segment.fillEnd, "BOTTOM" .. finish)
        segment.divider:ClearAllPoints()
        segment.divider:SetPoint("TOP", segment.fillEnd, "TOP" .. finish)
        segment.divider:SetPoint("BOTTOM", segment.fillEnd, "BOTTOM" .. finish)
        segment.refresh:ClearAllPoints()
        segment.refresh:SetPoint("TOP", segment.fillEnd, "TOP" .. finish)
        segment.refresh:SetPoint("BOTTOM", segment.fillEnd, "BOTTOM" .. finish)
    end
    w.refresh:ClearAllPoints()
    w.refresh:SetPoint("TOP", w.span, "TOP" .. finish)
    w.refresh:SetPoint("BOTTOM", w.span, "BOTTOM" .. finish)

    local lists = ns.lists
    local style = ns.findById(lists.fills, db.plateFillTexture)
    local path = (style.path and not style.gradient) and style.path or nil
    local wrap = style.tiled and "REPEAT" or nil
    w.fill:SetShown(path ~= nil and db.plateDotColors == "single")
    if path then
        w.fill:SetTexture(path, wrap, wrap)
        w.fill:SetHorizTile(style.tiled or false)
        w.fill:SetVertTile(style.tiled or false)
        if style.raw then
            local _, _, _, alpha = ns.colorOf(db.plateFillColor, db.plateFillOpacity)
            w.fill:SetVertexColor(1, 1, 1, alpha) -- a texture with colours of its own
        else
            w.fill:SetVertexColor(ns.colorOf(db.plateFillColor, db.plateFillOpacity))
        end
    end
    for _, segment in ipairs(w.segments) do
        segment.texture:SetTexture(path or WHITE, wrap, wrap)
        segment.texture:SetHorizTile(style.tiled or false)
        segment.texture:SetVertTile(style.tiled or false)
    end

    local r, g, b, a = ns.colorOf(db.plateOutlineColor, db.plateOutlineOpacity)
    for _, edge in ipairs(w.edges) do
        if db.plateOutlineStyle == "dashed" then
            local file = (edge.horizontal and "DashH" or "DashV") .. db.plateDashLength
            edge.texture:SetTexture(ns.textureDir .. file, "REPEAT", "REPEAT")
            edge.texture:SetHorizTile(edge.horizontal)
            edge.texture:SetVertTile(not edge.horizontal)
        else
            edge.texture:SetTexture(WHITE)
            edge.texture:SetHorizTile(false)
            edge.texture:SetVertTile(false)
        end
        if edge.horizontal then
            edge.texture:SetHeight(db.plateOutlineThickness)
        else
            edge.texture:SetWidth(db.plateOutlineThickness)
        end
        edge.texture:SetVertexColor(r, g, b, a)
        edge.texture:SetShown(db.plateOutlineStyle ~= "none")
    end

    local size = db.nameplateIconSize
    w.iconWindow:SetSize(size, size)
    w.iconBar:SetSize(ICON_BAR_LENGTH, size)
    w.icon:SetSize(size, size)
    w.icon:SetTexture(ns.findById(lists.icons, db.plateIcon).path)
    if w.swing then ns.SwingIcon.Style(w.swing, size, db.swingKill) end
    w.iconWindow:ClearAllPoints()
    local x, y = db.plateIconOffsetX, db.plateIconOffsetY
    if db.nameplateIconPosition == "left" then
        w.iconWindow:SetPoint("RIGHT", w.healthBar, "LEFT", -4 + x, y)
    elseif db.nameplateIconPosition == "above" then
        w.iconWindow:SetPoint("BOTTOM", w.healthBar, "TOP", x, 4 + y)
    elseif db.nameplateIconPosition == "below" then
        w.iconWindow:SetPoint("TOP", w.healthBar, "BOTTOM", x, -4 + y)
    else
        w.iconWindow:SetPoint("LEFT", w.healthBar, "RIGHT", 4 + x, y)
    end
end

local function hideWidgets(w)
    w.displayDamage = 0
    if ns.Retail and ns.Retail.UpdatePoisonOffset then ns.Retail.UpdatePoisonOffset(w.plate) end
    w.marker:Hide()
    w.iconWindow:Hide()
    w.iconArmed = nil
end

-- Draws one plate's widgets. maxHealth and health may be secret (real plates) or plain (the options preview):
-- they only ever go into StatusBar min/max, never into Lua math. Returns false if drawing failed.
local function drawPlate(w, entries, total, maxHealth, health, db, iconOnly, unit)
    keepAbove(w)
    applyStyle(w, db)
    local perDot = db.plateDotColors ~= "single"
    local count = perDot and math.min(#entries, MAX_SEGMENTS) or 0
    local ok = pcall(function()
        w.marker:SetMinMaxValues(0, maxHealth)
        w.marker:SetValue(total)
        local running = 0
        for i, segment in ipairs(w.segments) do
            local entry = entries[i]
            if i <= count then
                running = running + entry.damage
                -- The last segment also covers any DoTs beyond MAX_SEGMENTS.
                if i == count then running = total end
                local color = ns.dotColor(entry, db.plateDotColors)
                segment.texture:SetVertexColor(color[1], color[2], color[3], db.plateFillOpacity / 100)
            end
            segment.bar:SetMinMaxValues(0, maxHealth)
            segment.bar:SetValue(i <= count and running or total)
            segment.texture:SetShown(i <= count)
            segment.divider:SetShown(db.segmentDividers and i < count or false)
            if segment.refresh then
                segment.refresh:SetShown(i <= count and entry and entry.refreshDue and db.refreshCue ~= false or false)
            end
        end
        local anyDue = false
        if db.refreshCue ~= false then
            for _, entry in ipairs(entries) do
                if entry.refreshDue then anyDue = true break end
            end
        end
        if w.refresh then w.refresh:SetShown(anyDue and not perDot) end
        w.iconBar:SetMinMaxValues(0, health)
        w.iconBar:SetValue(ns.lethalDamage and ns.lethalDamage(entries, false) or total)
        if w.swing then ns.SwingIcon.Draw(w.swing, health, ns.lethalDamage and ns.lethalDamage(entries, unit ~= nil) or total) end
    end)
    if not ok then
        hideWidgets(w)
        return false
    end
    w.marker:SetShown(db.showMarkers and not iconOnly)
    w.displayDamage = db.showMarkers and not iconOnly and total or 0
    if ns.Retail and ns.Retail.UpdatePoisonOffset then ns.Retail.UpdatePoisonOffset(w.plate) end
    -- UI-3: the kill icon is part of the marker set: with showMarkers off it
    -- must hide too, not linger alone on the plate.
    -- A window going hidden -> shown renders one frame with the icon bar's stale/unlaid-out fill (full width),
    -- flashing the icon on every new DoT. Show it transparent first; the next draw (one refresh later) reveals it.
    if not (db.showMarkers and db.nameplateMode == "markerIcon" and (not unit or not ns.shielded(unit, entries))) then
        w.iconWindow:Hide()
        w.iconArmed = nil
    elseif w.iconArmed then
        w.iconWindow:SetAlpha(1)
    else
        w.iconWindow:SetAlpha(0)
        w.iconWindow:Show()
        w.iconArmed = true
    end
    return true
end

-- hangOn: a frame the marker should hang on instead of the widget host (the focus frame's bar, see Focus.lua). A marker
-- hung on the screen was never drawn on the unit frames of the Forever client; one on its bar is. The unit frames'
-- bars cannot be reparented to in combat, so the move waits for the end of it.
local function widgetsFor(plate, healthBar, hangOn)
    local w = widgetsByPlate[plate]
    if w then
        local host = BIT.Plate.WidgetHost(plate)
        if w.host ~= host then
            w.host = host
            w.iconWindow:SetParent(host)
        end
        local want = hangOn or host
        if w.markerHost ~= want then
            -- only a bar of a unit frame is off limits in combat: a plate's host is moved to whenever it changes, as before
            local restricted = hangOn ~= nil or w.hungOn ~= nil
            if not (restricted and type(InCombatLockdown) == "function" and InCombatLockdown()) then
                w.marker:SetParent(want)
                w.markerHost, w.hungOn = want, hangOn
            end
        end
        if hangOn and BIT.OwnOverlays then BIT.OwnOverlays[w.marker] = true end
        if w.healthBar == healthBar then
            fitMarker(w)
            return w
        end
        -- UI-1: the client recycles the plate frame between mobs with a new
        -- health bar object. Reuse the single widget set and re-anchor it
        -- instead of building a second set and leaking the first.
        w.healthBar = healthBar
        fitMarker(w)
        -- the icon is anchored to w.healthBar in applyStyle, which exits
        -- early when the style signature is unchanged: force it to re-run
        -- so the icon follows the marker to the new bar.
        w.signature = nil
        return w
    end
    return createWidgets(plate, healthBar)
end

local function updatePlate(unit, plate, db)
    local w0 = widgetsByPlate[plate]
    -- A plate with no DoT is the common case: it hides at once, before the death check below.
    local entries, total = ns.dotBreakdownForUnit(unit)
    if total <= 0 then
        if w0 then hideWidgets(w0) end
        return
    end
    -- UI-2: a dead mob's marker must hide at once, not hang until expiry.
    -- Read defensively: on Forever the answer can be secret in combat,
    -- and a secret must never hide a living mob's marker (nor error out).
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok and not isSecret(dead) and dead == true then
            if w0 then hideWidgets(w0) end
            return
        end
    end
    local healthBar = findHealthBar(plate)
    local iconOnly = not healthBar
    if iconOnly and db.nameplateMode ~= "markerIcon" then
        if w0 then hideWidgets(w0) end
        return
    end
    -- Without a visible bar, seat only the native health-clipped kill icon beside the plate.
    drawPlate(widgetsFor(plate, healthBar or plate), entries, total,
        UnitHealthMax(unit), UnitHealth(unit), db, iconOnly, unit)
end

-- For Focus.lua: the same widgets on another health bar (the focus frame's), hosted by a frame of its own.
-- A widget set marked pinned belongs to its owner, which hides it itself: the plate refresh leaves it alone.
ns.barMarker = { widgetsFor = widgetsFor, draw = drawPlate, hide = hideWidgets }

function ns.nameplateDamageBase(plate, bar)
    local w = widgetsByPlate[plate]
    return w and w.healthBar == bar and w.displayDamage or 0
end

-- The options window's mock nameplate: { plate, healthBar } plus its preview state ({ health, dots } in % of
-- max health), or nil. Drawn by the same code as real plates, with plain numbers.
local previewPlate, previewState

function ns.setPlatePreview(host, state)
    local old = previewPlate
    previewPlate, previewState = host, state
    if old and not host then
        local w = widgetsByPlate[old.plate]
        if w then hideWidgets(w) end
    end
end

local function updatePreviewPlate(db)
    if type(previewPlate.healthBar.SetReverseFill) == "function" then
        previewPlate.healthBar:SetReverseFill(db.plateFillDirection == "rtl")
    end
    local entries, total = {}, 0
    for _, dot in ipairs(previewState.dots) do
        if dot.damage > 0 then
            table.insert(entries, dot)
            total = total + dot.damage
        end
    end
    local w = widgetsFor(previewPlate.plate, previewPlate.healthBar)
    -- UI-4: a dead mock shows "Target died", not widgets on a corpse.
    if total <= 0 or db.nameplateMode == "off" or (previewState.health or 1) <= 0 then return hideWidgets(w) end
    drawPlate(w, entries, total, 100, math.max(previewState.health, 0.01), db)
end

local seenPlates = {}
local PLATE_UNITS = {} -- "nameplate1".."nameplateN", built once so the 10 Hz refresh makes no strings
for i = 1, MAX_PLATES do PLATE_UNITS[i] = "nameplate" .. i end
local function refreshPlates()
    local db = ns.db
    wipe(seenPlates)
    if db and previewPlate and previewState then
        seenPlates[previewPlate.plate] = true
        updatePreviewPlate(db)
    end
    if db and db.nameplateMode ~= "off" and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        for i = 1, MAX_PLATES do
            local unit = PLATE_UNITS[i]
            if UnitExists(unit) then
                local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
                local forbidden = ok and plate and plate.IsForbidden and plate:IsForbidden()
                if ok and plate and not forbidden then
                    seenPlates[plate] = true
                    updatePlate(unit, plate, db)
                end
            end
        end
    end
    for plate, w in pairs(widgetsByPlate) do
        if not seenPlates[plate] and not w.pinned then hideWidgets(w) end
    end
end

local driver = CreateFrame("Frame")
local sinceUpdate = 0
local reportedError = false
driver:SetScript("OnUpdate", function(self, elapsed)
    -- switched off in Ready2QuestCombat (Core.lua decides at ADDON_LOADED): stop for good
    if ns.off then self:SetScript("OnUpdate", nil) return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    local ok, err = pcall(refreshPlates)
    if not ok and not reportedError and ns.trace then
        reportedError = true
        ns.trace("ERROR in nameplate update: " .. tostring(err))
        ns.print("Nameplate display error (logged): " .. tostring(err))
    end
end)
if BIT.Perf then BIT.Perf.Watch(driver, "OnUpdate", "DoTInfo.plates") end

local function testBar(i)
    if not testBars[i] then
        local bar = CreateFrame("StatusBar", nil, UIParent)
        bar:SetSize(TEST_BAR_WIDTH, TEST_BAR_HEIGHT)
        bar:SetStatusBarTexture(WHITE)
        bar:SetStatusBarColor(1, 0, 1, 1)
        bar:SetFrameStrata("HIGH")
        local back = bar:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0, 0, 0, 0.8)
        bar:Hide()
        testBars[i] = bar
    end
    return testBars[i]
end

local hider = CreateFrame("Frame")
hider:Hide()
hider:SetScript("OnUpdate", function(self)
    if GetTime() < hideTestBarsAt then return end
    for _, bar in ipairs(testBars) do bar:Hide() end
    self:Hide()
end)

-- Checks one nameplate unit; returns a log line and whether the test bar could be shown.
local function probePlate(unit, index)
    local parts = { unit }
    table.insert(parts, "guid=" .. call(UnitGUID, unit))
    table.insert(parts, "attackable=" .. call(UnitCanAttack, "player", unit))
    table.insert(parts, "health=" .. call(UnitHealth, unit))
    table.insert(parts, "max=" .. call(UnitHealthMax, unit))

    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        table.insert(parts, "plate API missing")
        return table.concat(parts, " "), false
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok then
        table.insert(parts, "plate: error " .. tostring(plate))
        return table.concat(parts, " "), false
    end
    if not plate then
        table.insert(parts, "plate: nil")
        return table.concat(parts, " "), false
    end
    local forbidden = plate.IsForbidden and plate:IsForbidden()
    table.insert(parts, "forbidden=" .. tostring(forbidden))
    if forbidden then return table.concat(parts, " "), false end

    local healthBar, path = findHealthBar(plate)
    table.insert(parts, "healthBar=" .. path)
    local function layout(name, region)
        table.insert(parts, name .. "=" .. geometry(region))
    end
    layout("plateRect", plate)
    layout("unitRect", plate.UnitFrame)
    layout("containerRect", plate.UnitFrame and plate.UnitFrame.HealthBarsContainer)
    if healthBar then
        table.insert(parts, "barForbidden=" .. tostring(healthBar.IsForbidden and healthBar:IsForbidden() or false))
        table.insert(parts, "barSize=" .. call(healthBar.GetWidth, healthBar) .. "x" .. call(healthBar.GetHeight, healthBar))
        table.insert(parts, "barScale=" .. call(healthBar.GetEffectiveScale, healthBar))
        table.insert(parts, "barVisible=" .. call(healthBar.IsVisible, healthBar))
        layout("barRect", healthBar)
        local textureOK, texture = pcall(healthBar.GetStatusBarTexture, healthBar)
        if textureOK then layout("barFillRect", texture) end
        layout("barBackgroundRect", healthBar.bgTexture)
        layout("selectedBorderRect", healthBar.selectedBorder)
    end
    -- Where the marker has to be drawn above: the frame levels and strata of the plate, its unit frame, the
    -- bar, the bar's own child frames, and the marker if there is one.
    local function layer(name, f)
        if type(f) ~= "table" then return end
        table.insert(parts, name .. "=" .. call(f.GetFrameStrata, f) .. "/" .. call(f.GetFrameLevel, f))
    end
    layer("plateLayer", plate)
    layer("unitFrameLayer", plate.UnitFrame)
    layer("barLayer", healthBar)
    if healthBar and healthBar.GetChildren then
        local children = { pcall(healthBar.GetChildren, healthBar) }
        for i = 2, #children do layer("barChild" .. (i - 1), children[i]) end
    end
    local w = widgetsByPlate[plate]
    if w then
        layer("markerLayer", w.marker)
        table.insert(parts, "markerShown=" .. call(w.marker.IsShown, w.marker))
        table.insert(parts, "markerSize=" .. call(w.marker.GetWidth, w.marker) .. "x" .. call(w.marker.GetHeight, w.marker))
        table.insert(parts, "markerScale=" .. call(w.marker.GetEffectiveScale, w.marker))
        table.insert(parts, "markerVisible=" .. call(w.marker.IsVisible, w.marker))
        layout("markerRect", w.marker)
        layout("spanRect", w.span)
        layout("fillRect", w.fill)
        layout("segmentBarRect", w.segments[1].bar)
        layout("segmentEndRect", w.segments[1].fillEnd)
        layout("segmentTextureRect", w.segments[1].texture)
    end

    local bar = testBar(index)
    bar:ClearAllPoints()
    local anchorOK, anchorErr = pcall(bar.SetPoint, bar, "BOTTOM", plate, "TOP", 0, 2)
    table.insert(parts, "anchorPlate=" .. (anchorOK and "ok" or ("error " .. tostring(anchorErr))))
    if healthBar then
        local probeAnchor = testBar(MAX_PLATES + 1)
        probeAnchor:ClearAllPoints()
        local ok2, err2 = pcall(probeAnchor.SetPoint, probeAnchor, "TOPLEFT", healthBar, "TOPLEFT")
        table.insert(parts, "anchorHealthBar=" .. (ok2 and "ok" or ("error " .. tostring(err2))))
        probeAnchor:ClearAllPoints()
        probeAnchor:Hide()
    end
    local feedOK, feedErr = pcall(function()
        bar:SetMinMaxValues(0, UnitHealthMax(unit))
        bar:SetValue(UnitHealth(unit))
    end)
    table.insert(parts, "feedHealth=" .. (feedOK and "ok" or ("error " .. tostring(feedErr))))

    local shown = anchorOK and feedOK
    if shown then bar:Show() end
    return table.concat(parts, " "), shown
end

function ns.probeNameplates()
    local inInstance, instanceType = IsInInstance()
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    ns.trace("PLATES geometryProbe=2 version=" .. call(metadata, ADDON_NAME, "Version")
        .. " retail=" .. tostring(ns.Retail ~= nil) .. " build=" .. call(GetBuildInfo)
        .. " UIParent=" .. geometry(UIParent))
    local getCVar = C_CVar and C_CVar.GetCVar or GetCVar
    local settings = {}
    for _, name in ipairs({ "nameplateSize", "nameplateStyle", "nameplateGlobalScale",
        "NamePlateHorizontalScale", "NamePlateVerticalScale", "nameplateSelectedScale",
        "nameplateMinScale", "nameplateMaxScale", "uiScale", "useUiScale" }) do
        table.insert(settings, name .. "=" .. call(getCVar, name))
    end
    ns.trace("PLATES settings " .. table.concat(settings, " "))
    ns.trace(string.format("PLATES probe: C_NamePlate=%s GetNamePlateForUnit=%s instance=%s (%s) inCombat=%s",
        tostring(C_NamePlate ~= nil), tostring(C_NamePlate ~= nil and C_NamePlate.GetNamePlateForUnit ~= nil),
        tostring(inInstance), tostring(instanceType), call(UnitAffectingCombat, "player")))
    for _, bar in ipairs(testBars) do bar:Hide() end

    local found, shown = 0, 0
    for i = 1, MAX_PLATES do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            found = found + 1
            local line, ok = probePlate(unit, found)
            ns.trace("PLATES " .. line)
            if ok then shown = shown + 1 end
        end
    end

    hideTestBarsAt = GetTime() + TEST_SECONDS
    hider:Show()
    ns.trace(string.format("PLATES probe done: %d nameplates, %d test bars shown", found, shown))
    ns.print(string.format("Nameplate probe: %d nameplates found, %d magenta test bars shown for %d seconds. "
        .. "Results are in the log (/reload to save it).", found, shown, TEST_SECONDS))
end
