-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module CastPrediction: the settings tab (/upt castpred) with a live
-- preview. The window's left column holds the preview: the module's real marker drawn on mock
-- frames (Core/Preview.lua) and fed plain numbers, the same way DoTInfo's preview does; the right
-- column holds the settings, split into sub-tabs.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("CastPrediction")

local WINDOW_WIDTH, WINDOW_HEIGHT = 840, 500
local PREVIEW_WIDTH = 290
local COL_HEIGHT = 440
local ROW_HEIGHT = 26
local SIDE = 12
local HEALTH_SCALE = 10 -- the mock bars are 0..100; the marker works on a 0..1000 health scale

local window
local areas
local tabButtons
local controls = {}
local panel
local hostsSet = false
local preview = { health = 35, spell = 3 } -- TRY IT: a lethal Shadow Bolt by default, never settings

-- The sample casts the preview walks through, in the order of the button.
local SAMPLE_SPELLS = {
    { name = "Frostbolt",      spellID = 116,   min = 410, max = 450, school = 16 },
    { name = "Fireball",       spellID = 133,   min = 600, max = 760, school = 4 },
    { name = "Shadow Bolt",    spellID = 686,   min = 480, max = 540, school = 32 },
    { name = "Lightning Bolt", spellID = 403,   min = 430, max = 490, school = 8 },
    { name = "Pyroblast",      spellID = 11366, min = 780, max = 980, school = 4 },
    { name = "Arcane Missiles (channel)", spellID = 5143, min = 280, max = 320, school = 64, channel = true },
    { name = "Eviscerate",     spellID = 2098,  min = 410, max = 500, school = 1, preview = true },
    { name = "Ferocious Bite", spellID = 22568, min = 520, max = 640, school = 1, preview = true },
}

local function db() return ns._settings() end

local function currentSpell()
    return SAMPLE_SPELLS[preview.spell] or SAMPLE_SPELLS[1]
end

-- The sample's range uses the selected estimate against a mock target on a 0..1000 scale.
local function previewState()
    local spell = currentSpell()
    local health = preview.health * HEALTH_SCALE
    local estimate = db().estimate
    return {
        name = spell.name,
        spellID = spell.spellID,
        min = spell.min,
        max = spell.max,
        value = estimate == "min" and spell.min or estimate == "max" and spell.max
            or (spell.min + spell.max) / 2,
        school = spell.school,
        channel = spell.channel,
        preview = spell.preview,
        health = health,
        maxHealth = 100 * HEALTH_SCALE,
    }
end

local function refreshControls()
    for _, control in ipairs(controls) do
        if control.Refresh then control:Refresh() end
    end
end

local function inCombat()
    return (type(InCombatLockdown) == "function" and InCombatLockdown())
        or (type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player")) or false
end

local function updatePreview()
    if not panel then return end
    ns.setPreviewState(hostsSet and not inCombat() and previewState() or nil)
    if panel.targetHealthBar then panel.targetHealthBar:SetValue(preview.health) end
    if panel.plateHealthBar then panel.plateHealthBar:SetValue(preview.health) end
    if panel.healthPercent then panel.healthPercent:SetText(string.format("%d%%", preview.health)) end
    if panel.healthValue then panel.healthValue:SetText(tostring(preview.health * 10)) end
    if panel.spellButton then panel.spellButton:SetText(currentSpell().name) end
    if panel.healthSlider then panel.healthSlider:Refresh() end
    ns._refresh()
end

local function changed()
    ns.InvalidateView()
    refreshControls()
    updatePreview()
end

local function releasePreview()
    ns.setPreviewState(nil)
    ns.setDisplayHost(nil)
    ns.setPlatePreview(nil)
end

-- The preview takes the display over out of combat; in combat the real target keeps it, exactly
-- like DoTInfo's preview.
local function syncDisplayHost()
    if not (panel and window and window:IsVisible()) then return end
    if inCombat() then
        if panel.combatNote then panel.combatNote:Show() end
        if hostsSet then
            hostsSet = false
            releasePreview()
            ns._refresh()
        end
    elseif not hostsSet then
        hostsSet = true
        if panel.combatNote then panel.combatNote:Hide() end
        ns.setDisplayHost(panel.host)
        ns.setPlatePreview(panel.plateHost)
        updatePreview()
    end
end

---------------------------------------------------------------------------------------------
-- Row builders: the core's own widgets, placed in a column
---------------------------------------------------------------------------------------------

local tabKeys -- the settings keys of the sub-tab being built, for its "Reset this tab"
local function note(key)
    if tabKeys and key then tabKeys[#tabKeys + 1] = key end
end

-- The rows are the shared ones (Core/LookRows.lua), the same widgets, geometry and wording in every module.
local function place(row, y, height)
    table.insert(controls, row)
    return BIT.UI.PlaceRow(row, y, row.standard and row:GetHeight() or height or ROW_HEIGHT)
end

local function checkRow(parent, labelText, key, tooltip)
    note(key)
    return BIT.Looks.Rows.Check(parent, labelText, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, { tooltip = tooltip, settings = db })
end

local function sliderRow(parent, labelText, key, min, max, step, format, tooltip)
    note(key)
    local opts = { tooltip = tooltip, settings = db }
    if type(format) == "function" then opts.display = format elseif key:find("Opacity$") then opts.suffix = "%" end
    return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, opts)
end

-- A drop-down for colours (with a custom colour), textures, icons and plain lists alike.
local function choiceRow(parent, labelText, key, list, tooltip)
    note(key)
    return BIT.Looks.Rows.Choice(parent, labelText, list, function() return db()[key] end, function(id)
        db()[key] = id
        changed()
    end, { tooltip = tooltip, settings = db })
end

local function buttonRow(parent, labelText, buttonText, onClick, tooltip)
    return BIT.Looks.Rows.Button(parent, labelText, buttonText, function()
        onClick()
        changed()
    end, { tooltip = tooltip, settings = db })
end

-- A drop-down over a table of choices; get/set work on any value (Auto is the absence of a value).
local function forceRow(parent, labelText, choices, get, set, tooltip)
    return BIT.Looks.Rows.Choice(parent, labelText, choices, function() return get() or "auto" end, function(id)
        set(id ~= "auto" and id or nil)
        changed()
    end, { tooltip = tooltip, settings = db })
end

-- One curated talent of the player's class: Auto (the client's tree answers) / Off / Max rank.
-- The force lives in settings.talentForce[key]; Auto is the absence of a value.
local TALENT_CHOICES = {
    { id = "auto", label = "Auto (detect)" },
    { id = "off",  label = "Off" },
    { id = "max",  label = "Max rank" },
}
local function talentForceRow(parent, entry, tooltip)
    note("talentForce")
    return forceRow(parent, entry.en, TALENT_CHOICES,
        function()
            local force = db().talentForce
            return force and force[entry.key] or nil
        end,
        function(value)
            db().talentForce = db().talentForce or {}
            db().talentForce[entry.key] = value
        end, tooltip)
end

-- One curated aura: Auto (read it when the client shows it) / Off.
local AURA_CHOICES = {
    { id = "auto", label = "Auto (read)" },
    { id = "off",  label = "Off" },
}
local function auraForceRow(parent, entry, tooltip)
    note("auraForce")
    return forceRow(parent, string.format("%s (%s)", entry.en, entry.unit), AURA_CHOICES,
        function()
            local force = db().auraForce
            return force and force[entry.key] or nil
        end,
        function(value)
            db().auraForce = db().auraForce or {}
            db().auraForce[entry.key] = value
        end, tooltip)
end

-- A section header, with room above it once there is something above it.
local function section(parent, y, text)
    if y > 0 then y = y + 8 end
    return place(BIT.UI.Header(parent, text), y, 28)
end

-- A wrapped note; the next row starts below its measured height.
local NOTE_WIDTH = 470
local function noteRow(parent, y, text)
    local row = BIT.UI.Note(parent, text, NOTE_WIDTH)
    return place(row, y + 4, row:GetHeight() + 10)
end

local function colorList(school)
    return BIT.Looks.ColorList(school and { { id = "school", label = "Spell school" } } or nil)
end

local function textureList()
    return BIT.Looks.Textures()
end

---------------------------------------------------------------------------------------------
-- The sub-tabs of the right column
---------------------------------------------------------------------------------------------

local function buildMarkerTab(parent)
    local y = section(parent, 0, "FRAMES")
    y = place(checkRow(parent, "Show on target frame", "showTargetFrame",
        "Show the prediction on the Blizzard or configured target frame."), y)
    local retail = ns.Talents and ns.Talents.IsRetail and ns.Talents.IsRetail()
    y = place(checkRow(parent, "Show mana cost on your mana bar", "showManaCost",
        retail and "While you cast a spell with a cast time, marks its estimated mana cost on your mana bar."
        or "While you cast a spell with a cast time, marks its estimated cost to the right of your remaining mana. "
            .. "This illustrates mana already spent, not another deduction."), y)
    y = place(checkRow(parent, "Show on focus frame", "showFocusFrame",
        "Also show the prediction on the focus frame when it represents the cast's target."), y)
    y = place(checkRow(parent, "Show on party frames", "showPartyFrames",
        "Show the prediction only if a party frame represents the cast's recipient. Ordinary damage casts target enemies, not party members."), y)
    y = place(checkRow(parent, "Show on raid frames", "showRaidFrames",
        "Show the prediction only if a raid frame represents the cast's recipient. Ordinary damage casts target enemies, not raid members."), y)
    y = place(checkRow(parent, "Show on nameplates", "showNameplates",
        "Show the prediction on the cast target's nameplate."), y)
    y = place(checkRow(parent, "Target beats mouseover", "targetOverMouseover",
        "For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon "
        .. "can't tell which of the two your spell goes to and hides the prediction. With this on, your target "
        .. "(or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, "
        .. "the prediction could then show on the wrong mob.)"), y)
    y = section(parent, y, "THE MARKER")
    y = place(checkRow(parent, "Show the marker", "showMarker",
        "The predicted damage, drawn across enabled health bars while a cast is in flight."), y)
    y = section(parent, y, "CASTS AND CHANNELS")
    y = place(choiceRow(parent, "Fill color", "fillColor", colorList(true),
        "Only your own cast is ever drawn on the bar."), y)
    y = place(sliderRow(parent, "Fill opacity", "fillOpacity", 0, 100, 5, nil,
        "How strongly the fill covers the health bar."), y, 40)
    y = place(choiceRow(parent, "Cast fill style", "castTexture", textureList(),
        "The fill of a cast in flight. Patterns, glass and bevel shadings, Blizzard's bar textures and every texture "
        .. "LibSharedMedia knows (ElvUI, Details, ...) are in the list; the fill color tints them."), y)
    y = place(choiceRow(parent, "Channel fill style", "channelTexture", textureList(),
        "The fill of a channel (the damage that remains): a pattern shows it is a channel, not a single hit."), y)
    y = place(choiceRow(parent, "Outline", "outlineStyle", {
        { id = "solid", label = "Solid" },
        { id = "none", label = "None" },
    }, "A hairline around the marker; it can pulse while the cast is in flight."), y)
    y = place(choiceRow(parent, "Outline color", "outlineColor", colorList(), nil), y)
    y = place(sliderRow(parent, "Outline opacity", "outlineOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(checkRow(parent, "Pulse the outline", "pulseOutline",
        "A soft breathing of the outline while the cast is in flight."), y)
    y = place(checkRow(parent, "Show kill icon", "showKillIcon",
        "An icon when even the lowest end of the cast's range would finish the target. "
        .. "With secret health, native clipping can reveal part of the icon shortly before lethal."), y)
    y = place(checkRow(parent, "Show killing spell icon", "showKillSpellIcon",
        "Enabled by default. When a cast or finisher would kill, show its spell icon instead of the generic kill icon. "
        .. "The finisher preview uses the icon for the finisher that would kill."), y)
    y = place(choiceRow(parent, "Fallback kill icon", "killIcon", {
        { id = "skull", label = "Raid skull" },
        { id = "cross", label = "Red X" },
        { id = "impact", label = "Impact" },
    }, "Shown when the spell icon option is off or that spell's icon is unavailable."), y)
    y = place(sliderRow(parent, "Kill icon size", "killIconSize", 12, 128, 1, nil, nil), y, 40)
    y = place(choiceRow(parent, "Kill icon position", "killIconPosition", {
        { id = "portrait", label = "Portrait" },
        { id = "left", label = "Left of the bar" },
        { id = "right", label = "Right of the bar" },
        { id = "above", label = "Above the bar" },
        { id = "below", label = "Below the bar" },
    }, nil), y)
    y = place(sliderRow(parent, "Icon horizontal offset", "killIconOffsetX", -60, 60, 1, nil, nil), y, 40)
    y = place(sliderRow(parent, "Icon vertical offset", "killIconOffsetY", -60, 60, 1, nil, nil), y, 40)
    y = section(parent, y, "FINISHER PREVIEW")
    y = place(choiceRow(parent, "Preview fill style", "finisherTexture", textureList(),
        "The fill of the finisher preview (Prediction tab), so it never reads as a real cast."), y)
    y = place(choiceRow(parent, "Preview fill color", "finisherColor", colorList(true),
        "Spell school, one of the colors, or a custom color from the picker. A fill style from the Colorful group "
        .. "(the default, Flame) has colors of its own and ignores this color; only its opacity applies."), y)
    y = place(sliderRow(parent, "Preview fill opacity", "finisherOpacity", 0, 100, 5, nil, nil), y, 40)
    y = noteRow(parent, y, "The marker covers health backwards from the current HP edge. "
        .. "At 60/100 HP, 20 damage covers 60 down to 40. Overkill is clipped inside the bar.")
    return y
end

local function buildLabelTab(parent)
    local y = section(parent, 0, "THE TEXT")
    y = place(checkRow(parent, "Show text", "showLabel",
        "The spell name and the number, at the spot picked below."), y)
    y = place(choiceRow(parent, "Text shows", "labelMode", {
        { id = "amount", label = "Damage" },
        { id = "range", label = "Damage range" },
        { id = "percent", label = "Percent of the target's health" },
    }, "Damage is the single estimate picked on the Prediction tab; the range shows both ends; "
        .. "the percent needs a readable target health (out of combat in Forever)."), y)
    y = place(choiceRow(parent, "Text position", "labelPosition", {
        { id = "left", label = "Left of the bar" },
        { id = "center", label = "Centered on the bar" },
        { id = "right", label = "Inside the bar, right end" },
    }, nil), y)
    y = place(sliderRow(parent, "Text size", "labelSize", 8, 20, 1, nil, nil), y, 40)
    y = place(choiceRow(parent, "Text color", "labelColor", colorList(), nil), y)
    return y
end

local function buildNameplateTab(parent)
    local y = section(parent, 0, "NAMEPLATES")
    y = place(choiceRow(parent, "Nameplate style", "nameplateMode", {
        { id = "off", label = "Off" },
        { id = "marker", label = "Marker on the health bar" },
        { id = "markerIcon", label = "Marker and kill icon" },
    }, "The target's own plate gets the same marker, with its own colors; enemy bars are red."), y)
    y = place(choiceRow(parent, "Fill color", "plateFillColor", colorList(true), nil), y)
    y = place(sliderRow(parent, "Fill opacity", "plateFillOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(choiceRow(parent, "Outline", "plateOutlineStyle", {
        { id = "solid", label = "Solid" },
        { id = "none", label = "None" },
    }, nil), y)
    y = place(choiceRow(parent, "Outline color", "plateOutlineColor", colorList(), nil), y)
    y = place(sliderRow(parent, "Outline opacity", "plateOutlineOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(sliderRow(parent, "Icon size", "plateIconSize", 12, 128, 1, nil, nil), y, 40)
    y = place(choiceRow(parent, "Icon position", "plateIconPosition", {
        { id = "left", label = "Left of the bar" },
        { id = "above", label = "Above the bar" },
        { id = "below", label = "Below the bar" },
        { id = "right", label = "Right of the bar" },
    }, nil), y)
    y = place(sliderRow(parent, "Icon horizontal offset", "plateIconOffsetX", -40, 40, 1, nil, nil), y, 40)
    y = place(sliderRow(parent, "Icon vertical offset", "plateIconOffsetY", -40, 40, 1, nil, nil), y, 40)
    return y
end

local function buildPredictionTab(parent)
    local y = section(parent, 0, "THE PREDICTION")
    y = place(choiceRow(parent, "The marker shows", "estimate", {
        { id = "average", label = "Average of the range" },
        { id = "min", label = "Lowest of the range" },
        { id = "max", label = "Highest of the range" },
    }, "The expected damage the description and your spell power give."), y)
    y = place(checkRow(parent, "Only cast spells", "castOnly",
        "Show casts and channels. Instant spells are hidden unless this option is switched off."), y)
    y = place(checkRow(parent, "Finisher preview", "finisherPreview",
        "Rogues and druids: while your target has combo points, show on its health bar and plate what your strongest "
        .. "damage finisher on the action bars (Eviscerate, Ferocious Bite, a rune's Between the Eyes) would deal at "
        .. "that count. On Forever the description's numbers leave out attack power, so the real hit is at least this "
        .. "much. Damage-over-time finishers (Rupture, Rip) and combo point builders are not shown. Needs SpellDamageInfo."), y)
    y = place(checkRow(parent, "Learn from hits", "learn",
        "Every non-crit hit that matches the cast bends the estimate toward what you actually deal. "
        .. "On Retail the description already holds your spell power, so only physical hits are learned there: "
        .. "the target's armor takes a share off them that the description does not say."), y)
    y = place(checkRow(parent, "Manual spell power", "manualPower",
        "Use your own number instead of the client's reading, for testing or when the client hides it."), y)
    y = place(sliderRow(parent, "Spell power", "manualPowerValue", 0, 1200, 10, nil,
        "Applied through the spell's own coefficient, like the client's own reading would be."), y, 40)
    y = place(buttonRow(parent, "Learned factors", "Reset", function()
        ns.resetLearned()
    end, "Forget what earlier hits taught the estimate."), y)
    y = section(parent, y, "TALENTS (FOREVER)")
    local playerClass = ns.Talents and ns.Talents.PlayerClass and ns.Talents.PlayerClass() or nil
    local applicable = {}
    if ns.Talents and ns.Talents.LIST then
        for _, entry in ipairs(ns.Talents.LIST) do
            if entry.class == playerClass then applicable[#applicable + 1] = entry end
        end
    end
    if #applicable == 0 then
        y = noteRow(parent, y, "No curated passive talent multipliers for this class (or the character "
            .. "class could not be read). Retail tooltips already include talents, so nothing is added there.")
    else
        for _, entry in ipairs(applicable) do
            y = place(talentForceRow(parent, entry,
                "Auto reads the talent's rank from the client's talent tree (C_Traits). Off skips it; "
                .. "Max rank applies it without asking. Retail never adds talents: its descriptions hold them."), y)
        end
    end
    y = section(parent, y, "AURAS (READ WHEN VISIBLE)")
    y = place(checkRow(parent, "Include auras", "useAuras",
        "Buffs on you and debuffs on the target that the description does not hold: Arcane Power, "
        .. "Power Infusion, Improved Scorch, Curse of the Elements."), y)
    if ns.Auras and ns.Auras.LIST then
        for _, entry in ipairs(ns.Auras.LIST) do
            if (entry.class == nil or entry.class == playerClass) and ns.Auras.AppliesHere(entry) then
                y = place(auraForceRow(parent, entry,
                    "Auto applies this while the client shows it. WoW: Forever hides auras in combat, so there it "
                    .. "only ever applies out of combat; the hit calibration carries the rest. "
                    .. "/upt castpred auras prints what is readable right now."), y)
            end
        end
    end
    y = noteRow(parent, y, "The estimate is the description's own damage range plus your spell "
        .. "power through the spell's coefficient, the detected passive talents and the readable auras. "
        .. "Critical strikes roll about double, so a crit can outrun the marker: the prediction is an honest "
        .. "estimate, never a promise. /upt castpred talents and /upt castpred auras print what the client answers.")
    return y
end

local function buildTabs(parent, area)
    areas = {}
    tabButtons = {}
    local tabKeysByName, currentTab = {}, nil
    local function selectTab(name)
        currentTab = name
        for candidate, frame in pairs(areas) do
            frame:SetShown(candidate == name)
        end
        for candidate, button in pairs(tabButtons) do
            BIT.UI.TabSelected(button, candidate == name)
        end
    end
    local x = 6
    local builders = {
        Marker = buildMarkerTab, Text = buildLabelTab,
        Nameplates = buildNameplateTab, Prediction = buildPredictionTab,
    }
    for _, name in ipairs({ "Marker", "Text", "Nameplates", "Prediction" }) do
        -- Each sub-tab scrolls inside the column: the Prediction tab alone is taller than it.
        local frame = BIT.UI.ScrollColumn(area)
        frame:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -40)
        frame:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 40)
        frame:Hide()
        areas[name] = frame
        local button = CreateFrame("Button", nil, area, "PanelTopTabButtonTemplate")
        button:SetText(BIT.L(name))
        button.text = button:GetFontString()
        button:SetSize(BIT.UI.TabWidth(button.text), 26)
        button.text:SetPoint("CENTER")
        BIT.UI.SkinTabButton(button, button.text)
        button:SetPoint("TOPLEFT", x, -6)
        x = x + button:GetWidth() + BIT.UI.TAB_GAP
        button:SetScript("OnClick", function() selectTab(name) end)
        tabButtons[name] = button
        tabKeys = {}
        frame:Fit((builders[name](frame.content) or 0) + 12)
        tabKeysByName[name] = tabKeys
        tabKeys = nil
    end
    -- "Reset this tab": the same button, in the same place, as every other module; it resets the sub-tab that is open.
    local reset = BIT.Looks.ResetButton(area, function()
        for _, key in ipairs(tabKeysByName[currentTab] or {}) do
            -- the per-talent and per-aura choices are tables of overrides: back to none (a fresh table, never the default's)
            if key == "talentForce" or key == "auraForce" then db()[key] = {} else db()[key] = ns._defaults()[key] end
        end
        changed()
    end)
    reset:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -10, 10)
    selectTab("Marker")
    parent.castpredTabs = tabButtons
    parent.castpredAreas = areas
end

---------------------------------------------------------------------------------------------
-- The preview pane: mock target frame and nameplate, drawn by the real marker code
---------------------------------------------------------------------------------------------

local function buildPreview(pane)
    pane:SetSize(PREVIEW_WIDTH, COL_HEIGHT)
    BIT.UI.Backdrop(pane, 0.09)

    local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", SIDE, -12)
    title:SetText(BIT.L("Live preview"))
    local titleRule = pane:CreateTexture(nil, "ARTWORK")
    titleRule:SetColorTexture(unpack(BIT.UI.COLOR.divider))
    titleRule:SetHeight(1)
    titleRule:SetPoint("TOPLEFT", 8, -34)
    titleRule:SetPoint("TOPRIGHT", -8, -34)

    local scene = BIT.UI.Preview.Scene(pane, PREVIEW_WIDTH - 2 * SIDE, 216)
    scene:SetPoint("TOP", pane, "TOP", 0, -44)

    local mock = BIT.UI.Preview.TargetFrame(scene, { name = "Murloc Raider", level = "12", health = preview.health })
    mock.frame:SetPoint("TOP", scene, "TOP", 0, -6)
    pane.host = mock.host
    pane.targetHealthBar = mock.healthBar
    pane.healthPercent = mock.healthPercent
    pane.healthValue = mock.healthValue

    local plateMock = BIT.UI.Preview.Nameplate(scene, { name = "Murloc Raider", level = "12", health = preview.health })
    plateMock.frame:SetPoint("BOTTOM", scene, "BOTTOM", 0, 10)
    pane.plateHost = { plate = plateMock.frame, healthBar = plateMock.bar }
    pane.plateHealthBar = plateMock.bar

    -- While a fight is on, the marker is on the real target; the preview returns after combat.
    pane.combatNote = scene:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pane.combatNote:SetPoint("CENTER", scene, "CENTER")
    pane.combatNote:SetWidth(PREVIEW_WIDTH - 60)
    pane.combatNote:SetJustifyH("CENTER")
    pane.combatNote:SetText(BIT.L("In combat: the marker is on your target. The preview resumes after combat."))
    pane.combatNote:Hide()

    -- TRY IT: the preview's own numbers, never settings.
    local tryIt = BIT.Looks.TryItHeader(pane, scene)

    local healthSlider = BIT.Looks.PreviewSlider(pane, "Target health", 1, 100,
        function() return preview.health end,
        function(value)
            preview.health = math.max(1, math.min(100, math.floor(value + 0.5)))
            updatePreview()
        end)
    healthSlider:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -4, -4)
    pane.healthSlider = healthSlider

    local spellRow = CreateFrame("Frame", nil, pane)
    spellRow:SetHeight(ROW_HEIGHT)
    spellRow:SetPoint("TOPLEFT", healthSlider, "BOTTOMLEFT", 6, -2)
    spellRow:SetPoint("RIGHT", pane, "RIGHT", -SIDE, 0)
    local spellLabel = spellRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellLabel:SetPoint("LEFT", 0, 0)
    spellLabel:SetText(BIT.L("Sample spell"))
    pane.spellButton = BIT.UI.Button(spellRow, currentSpell().name, 150, function()
        preview.spell = preview.spell % #SAMPLE_SPELLS + 1
        updatePreview()
    end)
    pane.spellButton:SetPoint("RIGHT", spellRow, "RIGHT", 0, 0)

    local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", spellRow, "BOTTOMLEFT", 0, -10)
    hint:SetWidth(PREVIEW_WIDTH - 2 * SIDE)
    hint:SetJustifyH("LEFT")
    hint:SetText(BIT.L("Same marker on mock frames; sample damage is illustrative. Raise target health to hide "
        .. "the kill icon. While in combat, the marker returns to your target."))

    pane.title = title
    pane.hint = hint

    local sinceCheck = 0
    pane:SetScript("OnUpdate", function(self, elapsed)
        sinceCheck = sinceCheck + elapsed
        if sinceCheck < 0.25 then return end
        sinceCheck = 0
        syncDisplayHost()
    end)
end

-- The shared appearance pass the tab system runs on each rebuild.
local function renderPreview(sample, style)
    BIT.Style.ApplyText(sample.title, style, "text")
    BIT.Style.ApplyText(sample.label, style, "text")
end

---------------------------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------------------------

if BIT.RegisterTab then
    BIT.RegisterTab("CastPrediction", {
        title = "Cast prediction",
        summary = "The damage the spell you are casting should deal, drawn on enabled unit frames "
            .. "and the target's nameplate. Channels show estimated damage remaining until the channel ends. "
            .. "Crits, procs and resists cannot be predicted.",
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
        build = function(parent)
            if window == parent then return end
            window = parent
            controls = {}
            local note1 = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note1:SetPoint("TOPLEFT", 12, -6)
            note1:SetPoint("RIGHT", -12, 0)
            note1:SetJustifyH("LEFT")
            note1:SetText(BIT.L("The marker shows what the description and your spell power give; hits seen in "
                .. "combat tune it. Crits, procs and resists stay unpredictable."))

            local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            pane:SetPoint("TOPLEFT", 10, -46)
            buildPreview(pane)
            panel = pane

            local area = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            area:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
            area:SetSize(WINDOW_WIDTH - PREVIEW_WIDTH - 30, COL_HEIGHT)
            BIT.UI.Backdrop(area, 0.09)
            local divider = area:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(unpack(BIT.UI.COLOR.divider))
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", 8, -34)
            divider:SetPoint("TOPRIGHT", -8, -34)
            buildTabs(parent, area)

            refreshControls()
            updatePreview()
            syncDisplayHost()

            parent:SetScript("OnShow", function()
                updatePreview()
                syncDisplayHost()
            end)
            parent:SetScript("OnHide", function()
                -- The core keeps the built page and only hides it on a tab switch; the pane and the
                -- preview wiring must survive that, so only the display handover is released.
                hostsSet = false
                releasePreview()
            end)
            parent:RegisterEvent("PLAYER_REGEN_DISABLED")
            parent:RegisterEvent("PLAYER_REGEN_ENABLED")
            parent:SetScript("OnEvent", function() syncDisplayHost() end)
        end,
        buildPreview = function(pane)
            -- The core's OFF-scene sample: a static line naming the module, no live numbers.
            local sample = CreateFrame("Frame", nil, pane)
            sample:SetSize(PREVIEW_WIDTH, 90)
            sample.title = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sample.title:SetPoint("TOPLEFT", 12, -8)
            sample.title:SetText(BIT.L("CastPrediction sample"))
            sample.label = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            sample.label:SetPoint("TOPLEFT", 12, -34)
            sample.label:SetText(BIT.L("Frostbolt 410-450 (estimate)"))
            return sample
        end,
        previewRender = renderPreview,
        capabilities = { roles = { "text" }, shapes = false, geometry = false, border = false,
            font = true, scale = false, opacity = true },
    })
    BIT.tabWords.cast, BIT.tabWords.castpred = "CastPrediction", "CastPrediction"
end

if BIT.RegisterWaker then
    BIT.RegisterWaker("CastPrediction", function()
        ns.ensureDB()
    end)
end

ns.openOptions = function()
    if BIT.OpenSettings then BIT.OpenSettings("CastPrediction") end
end
