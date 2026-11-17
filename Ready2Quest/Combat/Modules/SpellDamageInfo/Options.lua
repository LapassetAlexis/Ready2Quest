-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: adapted from SpellDamageInfo/Options.lua at 8269edd.
-- Maintained directly in this module.
-- SpellDamageInfo: the settings window (/sdi) and its page in Options > AddOns.
-- Options window adapted from a standalone DoT addon by Joe Greive (MIT).
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
-- Portions Copyright (c) 2026 Joe Greive, used under the MIT licence; his notice is in LICENSE.
--
-- Left: a live preview, three mock action buttons (frames of our own, never real action
-- buttons) whose numbers are drawn by Core.lua's own ns.ButtonText and ns.DrawNumber, so the
-- preview shows exactly what the bars show. Right: the settings. Every change goes through
-- ns.SetSetting, which refreshes the real buttons.
--
-- The controls are built from basic widgets (CheckButton, Slider, Button) rather than Blizzard
-- templates, so they do not depend on templates behaving the same on every client. Nothing here
-- touches a secure frame or calls a protected function, so the window works in combat too.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Inside Ready2QuestCombat its own namespace; loaded on its own, the addon's table as before.
local ns = BIT.Module and BIT.Module("SpellDamageInfo") or BIT
local L, Estimate = ns.L, ns.Estimate

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WINDOW_WIDTH, WINDOW_HEIGHT = 660, 700
local HEADER_HEIGHT = 46
local PREVIEW_WIDTH = 250
local ROW_HEIGHT = BIT.Looks.ROW_HEIGHT
local LAYOUT = BIT.Looks.LAYOUT -- one geometry for every module's rows (Core/LookRows.lua)
local DISABLED_ALPHA = 0.35
local MOCK_SIZE = 36     -- a Blizzard action button, so the number gets the size it gets on the bar
local MOCK_SCALE = 1.5   -- the preview magnifies the whole button, number and all
local SIZE_STEP = 5

-- The preview's sample spells, as the parser would read them, with 50 spell power in every
-- school: Immolate r8 (direct and over time, 2 sec cast, the client's shares for spell 25309), a
-- pet's Screech (damage and a reduction next to it) and Curse of Weakness (a reduction alone);
-- under them, with a 2.6 sec weapon that hits for 120 on average, Heroic Strike (a weapon hit plus
-- 157) and Forever's Rockbiter Weapon (554 attack power, shown as what it adds to each hit).
local SAMPLE_POWER = { [2] = 50, [3] = 50, [4] = 50, [5] = 50, [6] = 50, [7] = 50 }
local SAMPLE_WEAPON = { melee = 120, meleeSpeed = 2.6 }
local PER_ROW = 4
-- A caption is no wider than its column: the columns are (PREVIEW_WIDTH + span) / (PER_ROW + 1)
-- apart, so a name wraps onto a second line rather than running into the next column's name.
local CAPTION_WIDTH = (PREVIEW_WIDTH + MOCK_SIZE * MOCK_SCALE) / (PER_ROW + 1) - 4
local SAMPLES = {
  { name = "OPT_SAMPLE_1", icon = "Interface\\Icons\\Spell_Fire_Immolation", hotkey = "1", castTime = 2,
    spellID = 25309,
    parsed = { school = "fire", direct = { min = 279, max = 279 }, dot = { total = 510, duration = 15 } } },
  { name = "OPT_SAMPLE_2", icon = "Interface\\Icons\\Ability_Hunter_Pet_Bat", hotkey = "2", castTime = 0,
    parsed = { direct = { min = 26, max = 46 } },
    reduction = { amount = 100, percent = false, stat = "attackpower" } },
  { name = "OPT_SAMPLE_3", icon = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth", hotkey = "3",
    reduction = { amount = 3, percent = false, stat = "damage" } },
  { name = "OPT_SAMPLE_4", icon = "Interface\\Icons\\Ability_Rogue_Ambush", hotkey = "4",
    weapon = { kind = "next", bonus = 157 } },
  { name = "OPT_SAMPLE_5", icon = "Interface\\Icons\\Spell_Nature_RockBiter", hotkey = "5",
    weapon = { kind = "ap", amount = 554 } },
  { name = "OPT_SAMPLE_6", icon = "Interface\\Icons\\Spell_Shadow_BurningSpirit", hotkey = "Mou...",
    view = { healthCost = 58, manaGain = 58 } },
  { name = "OPT_SAMPLE_7", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02", hotkey = "7",
    view = { transfer = true, direct = { min = 55, max = 55 }, heal = { min = 55, max = 55 } } },
  { name = "OPT_SAMPLE_8", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain", hotkey = "8",
    view = { healthCost = 58, petHeal = true } },
  { name = "OPT_SAMPLE_9", icon = "Interface\\Icons\\INV_Misc_Food_72", hotkey = "9",
    view = { hot = { total = 552, duration = 24 } } },
  { name = "OPT_SAMPLE_10", icon = "Interface\\Icons\\INV_Misc_Bandage_20", hotkey = "0",
    view = { heal = { min = 600, max = 600 } } },
  { name = "OPT_SAMPLE_11", icon = "Interface\\Icons\\INV_Drink_07", hotkey = "-",
    view = { manaOverTime = { total = 835, duration = 24 } } },
  -- a spell the parser cannot read: the average of its last casts (History.lua), marked with ~
  { name = "OPT_SAMPLE_12", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt", hotkey = "=",
    view = { history = { casts = 40 }, direct = { min = 412, max = 412, added = 0 }, castTime = 0 } },
}

local window
local controls = {} -- every settings row, refreshed after each change
local menu -- the shared choice list
local localized = {} -- widget -> locale key; refresh text without rebuilding its frame

local function localeKey(text)
  for key, value in pairs(L) do
    if value == text then return key end
  end
end

local function localizedText(widget, key)
  localized[widget] = key
  widget:SetText(L[key])
end

local function choiceLabel(entry)
  return entry.localeKey and L[entry.localeKey] or entry.label
end

local function db() return ns.GetSettings() end

local function say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSpellDamageInfo|r: " .. msg) end
end

local function findEntry(list, id)
  for _, entry in ipairs(list) do
    if entry.id == id then return entry end
  end
end

local function setBackdrop(frame, shade, alpha)
  BIT.UI.Backdrop(frame, shade, alpha)
end

---------------------------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------------------------

-- What the real bar would draw for a sample, under the current settings. On Retail the bars add
-- neither the estimate nor the weapon arithmetic (the descriptions hold the stats), so neither does this.
local function sampleText(sample)
  local view
  local retail = ns.IsRetail and ns.IsRetail()
  if sample.view then
    view = sample.view
  elseif sample.weapon then
    local w = db().weapon and not retail and ns.WeaponView(sample.weapon, SAMPLE_WEAPON) or nil
    view = w and { weapon = w } or nil
  elseif sample.parsed then
    local bonus = db().estimate and not retail and Estimate.DamageBonus(sample.parsed.school, SAMPLE_POWER) or nil
    local coef = sample.spellID and ns.SpellCoefficientsFor and ns.SpellCoefficientsFor(sample.spellID) or nil
    view = Estimate.Apply(sample.parsed, sample.castTime, bonus, nil, coef)
    if view then view.castTime = sample.castTime or 0 end
  end
  return ns.ButtonText(view, sample.reduction)
end

local function updatePreview()
  if not window then return end
  for widget, key in pairs(localized) do widget:SetText(L[key]) end
  for _, mock in ipairs(window.mocks) do
    local mainText, mainColor, sideText, sideColor, layout = sampleText(mock.sample)
    if db().button == "off" then mainText = nil end
    ns.DrawNumber(mock, mock.main, mock.side, mainText, mainColor, sideText, false, sideColor, layout)
  end
  window.offNote:SetShown(db().button == "off")
end

local function refreshControls()
  for _, row in ipairs(controls) do row:Refresh() end
end

local function changed()
  refreshControls()
  updatePreview()
end

local function set(key, value)
  if key == "interfaceLang" then
    ns.SetSetting(key, value)
    ns.SetInterfaceAndRefreshL(value)
    say(L.OPT_LANG_CHANGED)
  else
    ns.SetSetting(key, value)
  end
  changed()
end

local function mockButton(pane, sample, x, y)
  local mock = CreateFrame("Frame", nil, pane, "BackdropTemplate")
  mock:SetSize(MOCK_SIZE, MOCK_SIZE)
  mock:SetScale(MOCK_SCALE)
  -- offsets are in the mock's own (scaled) units
  mock:SetPoint("TOPLEFT", pane, "TOPLEFT", x / MOCK_SCALE, -y / MOCK_SCALE)
  mock:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
  mock:SetBackdropBorderColor(0, 0, 0, 1)
  local icon = mock:CreateTexture(nil, "BACKGROUND")
  icon:SetPoint("TOPLEFT", 1, -1)
  icon:SetPoint("BOTTOMRIGHT", -1, 1)
  icon:SetTexture(sample.icon)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  -- the hotkey, where Blizzard puts it, so the number's place can be judged against it
  local hotkey = mock:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
  hotkey:SetPoint("TOPRIGHT", mock, "TOPRIGHT", -2, -2)
  hotkey:SetText(sample.hotkey)
  mock.main = ns.NewLabel(mock)
  mock.side = ns.NewLabel(mock)
  mock.sample = sample

  local caption = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  caption:SetPoint("TOP", mock, "BOTTOM", 0, -6)
  caption:SetWidth(CAPTION_WIDTH)
  caption:SetJustifyH("CENTER")
  localizedText(caption, sample.name)
  mock.caption = caption
  return mock
end

local function buildPreview(pane)
  local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -12)
  localizedText(title, "OPT_PREVIEW")

  window.mocks = {}
  local span = MOCK_SIZE * MOCK_SCALE
  local gap = (PREVIEW_WIDTH - PER_ROW * span) / (PER_ROW + 1)
  for i, sample in ipairs(SAMPLES) do
    local row, col = math.floor((i - 1) / PER_ROW), (i - 1) % PER_ROW
    local inRow = math.min(PER_ROW, #SAMPLES - row * PER_ROW)
    -- a shorter row is centred under the one above it
    local shift = (PER_ROW - inRow) * (span + gap) / 2
    window.mocks[i] = mockButton(pane, sample, gap + shift + col * (span + gap), 44 + row * (span + 56))
  end

  window.offNote = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  window.offNote:SetPoint("TOP", pane, "TOP", 0, -44 - span - 36)
  localizedText(window.offNote, "OPT_PREVIEW_OFF")
  window.offNote:Hide()

  local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 12, 12)
  hint:SetWidth(PREVIEW_WIDTH - 24)
  hint:SetJustifyH("LEFT")
  localizedText(hint, "OPT_PREVIEW_HINT")
end

---------------------------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------------------------

-- Every row is the shared one (Core/LookRows.lua); this module only adds its translations (the label, the tooltip and the
-- names in a drop-down follow the chosen language, also while the window is open).
local function rowOpts(labelText, opts)
  opts = opts or {}
  local labelKey, tooltipKey = localeKey(labelText), opts.tooltip and localeKey(opts.tooltip)
  return { tooltip = opts.tooltip, enabledIf = opts.enabledIf, layout = opts.layout, suffix = opts.suffix,
    settings = db, register = function(row) controls[#controls + 1] = row end,
    localize = function(fontString) localizedText(fontString, labelKey) end,
    tooltipFor = opts.tooltip and function()
      local body = L[tooltipKey] or opts.tooltip
      if opts.retailNote and ns.IsRetail() then body = body .. " " .. L.OPT_RETAIL end
      return L[labelKey] or labelText, body
    end or nil,
    labelOf = choiceLabel }
end

local function makeRow(parent, labelText, opts)
  return BIT.Looks.Rows.Row(parent, labelText, rowOpts(labelText, opts))
end

local function checkbox(parent, key, labelText, opts)
  return BIT.Looks.Rows.Check(parent, labelText, function() return db()[key] end, function(value) set(key, value) end,
    rowOpts(labelText, opts))
end

-- /sdi size takes any whole number, so the slider shows it as it is.
local function slider(parent, key, labelText, min, max, step, opts)
  return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, function() return db()[key] end, function(value) set(key, value) end,
    rowOpts(labelText, opts))
end

local function closeMenu()
  if BIT.Looks then BIT.Looks.ClosePickList() end
end

local function choice(parent, key, labelText, list, opts)
  for _, entry in ipairs(list) do entry.localeKey = localeKey(entry.label) end
  return BIT.Looks.Rows.Choice(parent, labelText, list, function() return db()[key] end, function(id) set(key, id) end,
    rowOpts(labelText, opts))
end

local function pushButton(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  localizedText(button, localeKey(text))
  button:SetScript("OnClick", onClick)
  return BIT.UI.SkinButton(button)
end

---------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------

local function numbersShown(settings) return settings.button ~= "off" end

local function buildSettings(area)
  local rows, y = {}, 0
  local function place(key, row)
    row:SetPoint("TOPLEFT", area, "TOPLEFT", 8, -12 - y)
    y = y + (row.standard and row:GetHeight() or ROW_HEIGHT)
    rows[key] = row
  end
  place("button", choice(area, "button", L.OPT_BUTTON, {
    { id = "total", label = L.OPT_BUTTON_TOTAL },
    { id = "direct", label = L.OPT_BUTTON_DIRECT },
    { id = "dps", label = L.OPT_BUTTON_DPS },
    { id = "off", label = L.OPT_BUTTON_OFF },
  }, { tooltip = L.OPT_BUTTON_TIP }))
  place("size", slider(area, "size", L.OPT_SIZE, ns.SIZE_MIN, ns.SIZE_MAX, SIZE_STEP,
    { suffix = "%", tooltip = L.OPT_SIZE_TIP, enabledIf = numbersShown }))
  place("position", choice(area, "position", L.OPT_POSITION, {
    { id = "bottom", label = L.OPT_POS_BOTTOM },
    { id = "center", label = L.OPT_POS_CENTER },
    { id = "top", label = L.OPT_POS_TOP },
  }, { tooltip = L.OPT_POSITION_TIP, enabledIf = numbersShown }))
  place("sidePosition", choice(area, "sidePosition", L.OPT_SIDE, {
    { id = "opposite", label = L.OPT_SIDE_OPPOSITE },
    { id = "bottom", label = L.OPT_SIDE_BOTTOM },
    { id = "top", label = L.OPT_SIDE_TOP },
  }, { tooltip = L.OPT_SIDE_TIP, enabledIf = numbersShown }))
  place("skipUtilityBars", checkbox(area, "skipUtilityBars", L.OPT_SKIP_BARS,
    { tooltip = L.OPT_SKIP_BARS_TIP, enabledIf = numbersShown }))
  y = y + 8
  -- On Retail the descriptions already hold the player's stats, so both estimates stand down.
  local notRetail = function() return not ns.IsRetail() end
  place("estimate", checkbox(area, "estimate", L.OPT_ESTIMATE,
    { tooltip = L.OPT_ESTIMATE_TIP, retailNote = true, enabledIf = notRetail }))
  place("talents", checkbox(area, "talents", L.OPT_TALENTS,
    { tooltip = L.OPT_TALENTS_TIP, retailNote = true, enabledIf = notRetail }))
  place("tooltip", checkbox(area, "tooltip", L.OPT_TOOLTIP, { tooltip = L.OPT_TOOLTIP_TIP }))
  place("reduction", checkbox(area, "reduction", L.OPT_REDUCTION, { tooltip = L.OPT_REDUCTION_TIP }))
  place("weapon", checkbox(area, "weapon", L.OPT_WEAPON, { tooltip = L.OPT_WEAPON_TIP, retailNote = true, enabledIf = notRetail }))
  y = y + 8
  -- which kinds of number the buttons show (the weapon and the red reduction numbers have their own boxes above)
  place("showDamage", checkbox(area, "showDamage", L.OPT_SHOW_DAMAGE, { tooltip = L.OPT_SHOW_DAMAGE_TIP, enabledIf = numbersShown }))
  place("showDot", checkbox(area, "showDot", L.OPT_SHOW_DOT, { tooltip = L.OPT_SHOW_DOT_TIP, enabledIf = numbersShown }))
  place("showHeal", checkbox(area, "showHeal", L.OPT_SHOW_HEAL, { tooltip = L.OPT_SHOW_HEAL_TIP, enabledIf = numbersShown }))
  place("showHot", checkbox(area, "showHot", L.OPT_SHOW_HOT, { tooltip = L.OPT_SHOW_HOT_TIP, enabledIf = numbersShown }))
  place("showMana", checkbox(area, "showMana", L.OPT_SHOW_MANA, { tooltip = L.OPT_SHOW_MANA_TIP, enabledIf = numbersShown }))
  place("showAbsorb", checkbox(area, "showAbsorb", L.OPT_SHOW_ABSORB, { tooltip = L.OPT_SHOW_ABSORB_TIP, enabledIf = numbersShown }))
  y = y + 8
  place("useHistory", checkbox(area, "useHistory", L.OPT_HISTORY, { tooltip = L.OPT_HISTORY_TIP }))
  local forget = BIT.Looks.Rows.Button(area, L.OPT_HISTORY_ROW, L.OPT_HISTORY_CLEAR, function()
    if ns.History then ns.History.Clear() end
    ns.Refresh()
    say(L.HISTORY_CLEARED)
  end, rowOpts(L.OPT_HISTORY_ROW, { tooltip = L.OPT_HISTORY_CLEAR_TIP }))
  localizedText(forget.widget, "OPT_HISTORY_CLEAR")
  place("historyClear", forget)
  y = y + 8
  place("interfaceLang", choice(area, "interfaceLang", L.OPT_LANGUAGE, {
    { id = "auto", label = L.LANG_AUTO },
    { id = "en", label = L.LANG_EN },
    { id = "de", label = L.LANG_DE },
    { id = "ru", label = L.LANG_RU },
  }, { tooltip = L.OPT_LANGUAGE_TIP }))
  return rows, y
end

-- The preview and the settings, in window: the addon's own window, below its title bar, or
-- inside Ready2QuestCombat the tab it is built into.
local function buildContent(top)
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
  local endY
  window.rows, endY = buildSettings(area)

  window.reset = pushButton(area, L.OPT_RESET, 170, function()
    ns.ResetSettings()
    changed()
    say(L.OPT_RESET_DONE)
  end)
  -- Under the last row, wherever it ended (a long label wraps and makes its row taller, more so in another language): a
  -- button fixed to the bottom of the area lay over the last rows once the page had grown.
  window.reset:SetPoint("TOPRIGHT", area, "TOPRIGHT", -10, -(12 + endY + 10))

  window:SetScript("OnShow", changed)
  window:SetScript("OnHide", closeMenu)
end

local function createWindow()
  window = CreateFrame("Frame", "SpellDamageInfoOptions", UIParent, "BackdropTemplate")
  window:Hide() -- new frames start shown; ns.OpenOptions shows it, which runs OnShow
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
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SpellDamageInfoOptions") end -- Escape closes it

  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("SpellDamageInfo")
  title:SetTextColor(BIT.UI.COLOR.heading[1], BIT.UI.COLOR.heading[2], BIT.UI.COLOR.heading[3])

  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -8)

  buildContent(HEADER_HEIGHT)
end

function ns.OpenOptions()
  if BIT.OpenSettings then BIT.OpenSettings("SpellDamageInfo") return end
  if not window then createWindow() end
  if window:IsShown() then
    window:Hide()
  else
    window:SetFrameStrata("DIALOG")
    window:Show()
  end
end

-- /sdi changed something while the window is open.
function ns.OptionsChanged()
  if window and window:IsShown() then changed() end
end

-- Options > AddOns > SpellDamageInfo: a short page with a button that opens the window.
-- Returns which registration was used: "settings", "interface" or nil.
function ns.RegisterOptions()
  local function openSettings()
    -- The legacy InterfaceOptionsFrame may share our strata, so raise above it.
    local legacy = InterfaceOptionsFrame and InterfaceOptionsFrame.IsShown and InterfaceOptionsFrame:IsShown()
    if not (window and window:IsShown()) then ns.OpenOptions() end
    if legacy and window then window:SetFrameStrata("FULLSCREEN_DIALOG") end
  end
  if type(BIT.UI.RegisterSettingsLauncher) == "function"
      and BIT.UI.RegisterSettingsLauncher("SpellDamageInfo", L.OPT_PANEL_TEXT, openSettings) then return "settings" end
  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("SpellDamageInfo")
  title:SetTextColor(BIT.UI.COLOR.heading[1], BIT.UI.COLOR.heading[2], BIT.UI.COLOR.heading[3])
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  text:SetText(L.OPT_PANEL_TEXT)
  local open = pushButton(panel, "Open settings", 180, openSettings)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
  ns._optionsPanel, ns._optionsOpenButton = panel, open

  if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function"
    and type(Settings.RegisterAddOnCategory) == "function" then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "SpellDamageInfo")
    Settings.RegisterAddOnCategory(category)
    return "settings"
  elseif type(InterfaceOptions_AddCategory) == "function" then
    panel.name = "SpellDamageInfo"
    InterfaceOptions_AddCategory(panel)
    return "interface"
  end
  return nil
end

local loader = CreateFrame("Frame")
if not BIT.RegisterTab then loader:RegisterEvent("PLAYER_LOGIN") end
loader:SetScript("OnEvent", function()
  local ok, err = pcall(ns.RegisterOptions)
  if not ok then say("Options > AddOns page not added (" .. tostring(err) .. "); /sdi still opens the settings.") end
end)

-- BIT Minimal OFF-scene sample: static Immolate numbers (279 direct, 510
-- over 15 sec) as plain text, never live Estimate/DrawNumber output and
-- never real action buttons.
local function buildSDIPreview(parent)
  -- OFF previews can be opened before ADDON_LOADED wakes this module's locale.
  if not L.OVER then
    local saved = type(Ready2QuestCombat_SpellDamageInfoDB) == "table" and Ready2QuestCombat_SpellDamageInfoDB
    ns.InitInterfaceL(saved and saved.interfaceLang or "auto")
  end
  local scene = CreateFrame("Frame", nil, parent)
  scene:SetSize(560, 120)
  scene.title = scene:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scene.title:SetPoint("TOPLEFT", 12, -4)
  localizedText(scene.title, "OPT_OFF_SAMPLE")
  scene.main = scene:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  scene.main:SetPoint("TOPLEFT", 12, -30)
  scene.main:SetText("279")
  scene.main:SetHeight(14)
  scene.side = scene:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  scene.side:SetPoint("TOPLEFT", 12, -52)
  scene.side:SetText(string.format(L.OVER, "510", "15"))
  scene.side:SetHeight(14)
  return scene
end

local function renderSDIPreview(scene, style)
  scene.title:SetText(L.OPT_OFF_SAMPLE)
  scene.side:SetText(string.format(L.OVER, "510", "15"))
  BIT.Style.ApplyText(scene.title, style, "text")
  BIT.Style.ApplyText(scene.main, style, "text")
  BIT.Style.ApplyText(scene.side, style, "text")
  -- Native-Y min/max reflow: the two rows derive their depths and the scene
  -- its height from the shared font size; the window is never resized.
  local fontSize = style.fontSize or 12
  local mainDepth = 4 + fontSize + 8
  local sideDepth = mainDepth + fontSize + 4
  scene.main:ClearAllPoints()
  scene.main:SetPoint("TOPLEFT", 12, -mainDepth)
  scene.side:ClearAllPoints()
  scene.side:SetPoint("TOPLEFT", 12, -sideDepth)
  scene:SetSize(560, sideDepth + fontSize + 16)
end

if BIT.RegisterTab then
  BIT.RegisterTab("SpellDamageInfo", {
    title = "SpellDamageInfo",
    summary = "The damage and healing from each spell's description on your action buttons and in its tooltip.",
    width = WINDOW_WIDTH, height = WINDOW_HEIGHT - HEADER_HEIGHT + 10,
    build = function(parent)
      window = parent
      buildContent(10)
      changed()
    end,
    buildPreview = buildSDIPreview,
    previewRender = renderSDIPreview,
    capabilities = { roles = { "text" }, shapes = false,
      geometry = false, border = false, font = true, scale = false, opacity = true },
  })
  BIT.tabWords.sdi = "SpellDamageInfo"
end
