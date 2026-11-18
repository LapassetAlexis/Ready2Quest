-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the settings window (/upt). One tab per module, in the order the modules'
-- files load. Each module tab starts with Enable.
-- The module's own settings are built the first time the tab is shown while it runs, and
-- also the moment Enable is ticked while it is still off (a waker fills defaults only;
-- gameplay still starts at the next /reload). Opening a tab that is off does not wake it.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The window is made of plain frames (no secure templates, no protected calls), so it opens in
-- combat too.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local WHITE = "Interface\\Buttons\\WHITE8X8"
local HEADER_HEIGHT = 40
local TAB_HEIGHT = 26
local SWITCH_HEIGHT = 54
local MARGIN = 10
local SCROLL_BAR_WIDTH = 16
local DEFAULT_TAB = { width = 640, height = 360 }
local MAX_CONTENT_HEIGHT = 560 -- the window stays bounded; taller tabs scroll inside it

local SHORT_LABEL = {
  SpellDamageInfo = "Spells",
  CastPrediction = "Cast",
  DoTInfo = "DoTs",
  StatsInfo = "Stats",
  ResourceDing = "Points",
  Range = "Range",
  ShieldsInfo = "Shields",
  HealPrediction = "Heals",
  HunterRangeFinder = "Hunter",
  TriggerGlow = "Glow",
}

local window
local tabButtons, pages = {}, {}
local parkedPages = {} -- retain one off page and one prepared page per module
local current
local tabRows = 1

---------------------------------------------------------------------------------------------
-- Widgets shared by the modules of the core (StatsInfo, Range)
---------------------------------------------------------------------------------------------

local UI = BIT.UI or {} -- Appearance.lua (loaded before this file) may have added members
BIT.UI = UI

-- NeedRoll's Native skin: Blizzard's frame/buttons, black surfaces, gold headings and white text.
local TEX_DIR = "Interface\\AddOns\\Ready2Quest\\Combat\\Core\\Textures\\"
UI.MEDIA = {
  rounded = TEX_DIR .. "Rounded",
  border1 = TEX_DIR .. "RoundedBorder1",
  border2 = TEX_DIR .. "RoundedBorder2",
}
UI.COLOR = {
  panel = { 0, 0, 0, 1 },
  panelIn = { 0.02, 0.02, 0.02, 1 },
  edge = { 0.35, 0.35, 0.35, 1 },
  edgeOn = { 1, 0.82, 0, 0.8 },
  text = { 1, 1, 1, 1 },
  muted = { 0.63, 0.63, 0.63, 1 },
  heading = { 1, 0.82, 0, 1 },
  button = { 0.20, 0.05, 0.03, 1 },
  buttonHover = { 0.30, 0.08, 0.04, 1 },
  buttonHoverGlow = { 0.38, 0.12, 0.05, 1 },
  buttonDown = { 0.12, 0.03, 0.02, 1 },
  buttonOff = { 0.10, 0.10, 0.10, 1 },
  track = { 0.08, 0.08, 0.08, 1 },
  divider = { 1, 0.82, 0, 0.18 },
  danger = { 1, 0.125, 0.125, 1 },
}

local function sliced(parent, file, color, layer)
  local tex = parent:CreateTexture(nil, layer)
  tex:SetTexture(file)
  if type(tex.SetTextureSliceMargins) == "function" and type(tex.SetTextureSliceMode) == "function"
      and type(Enum) == "table" and Enum.UITextureSliceMode then
    pcall(tex.SetTextureSliceMargins, tex, 5, 5, 5, 5)
    pcall(tex.SetTextureSliceMode, tex, Enum.UITextureSliceMode.Stretched)
  end
  tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  tex:SetAllPoints()
  return tex
end

-- A rounded fill and (optionally) a rounded 1px or 2px outline drawn on the frame itself.
-- Returns both textures; frame.skinBg / frame.skinBorder address them for later tinting.
function UI.RoundedOn(frame, fill, border, thick)
  if type(frame) ~= "table" then return end
  frame.skinBg = sliced(frame, UI.MEDIA.rounded, fill, "BACKGROUND")
  if border then
    frame.skinBorder = sliced(frame, thick and UI.MEDIA.border2 or UI.MEDIA.border1, border, "BORDER")
  end
  return frame.skinBg, frame.skinBorder
end

-- Black inset panels, matching the game's tooltip/settings furniture.
function UI.Backdrop(frame, shade, alpha, thick)
  if type(frame) ~= "table" then return end
  if type(frame.SetBackdrop) == "function" then
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
      edgeSize = thick and 16 or 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0, 0, 0, alpha or 1)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  end
end

-- Keep UIPanelButtonTemplate's native art and its own hover/pressed/disabled states.
function UI.SkinButton(button, opts)
  if type(button) ~= "table" then return button end
  button:SetNormalFontObject("GameFontNormal")
  button:SetHighlightFontObject("GameFontHighlight")
  button:SetDisabledFontObject("GameFontDisable")
  return button
end

-- The track and thumb of a slider in the theme. The track is the rounded art stretched (a few
-- pixels tall, so its corners shrink with it; no slicing needed at this size).
function UI.SkinSlider(slider, thickness, vertical)
  if type(slider) ~= "table" then return slider end
  local track = slider.skinTrack
  if type(track) ~= "table" then
    track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(UI.MEDIA.rounded)
    slider.skinTrack = track
  end
  local size = thickness or 6
  track:ClearAllPoints()
  if vertical then
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    track:SetWidth(size)
  else
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(size)
  end
  local c = UI.COLOR.track
  track:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  local thumb = type(slider.GetThumbTexture) == "function" and slider:GetThumbTexture() or nil
  if type(thumb) == "table" and type(thumb.SetVertexColor) == "function" then
    pcall(thumb.SetVertexColor, thumb, 1, 1, 1, 1)
  end
  return slider
end

-- The same checkbox art as the game's own options.
function UI.SkinCheck(box)
  if type(box) ~= "table" then return box end
  box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  return box
end

-- A rounded hover wash for custom menu rows and choice buttons.
function UI.RoundHighlight(frame, color)
  if type(frame) ~= "table" then return end
  local c = color or { 1, 1, 1, 0.10 }
  local tex = frame:CreateTexture(nil, "HIGHLIGHT")
  tex:SetTexture(UI.MEDIA.rounded)
  if type(tex.SetTextureSliceMargins) == "function" and type(Enum) == "table" and Enum.UITextureSliceMode then
    pcall(tex.SetTextureSliceMargins, tex, 5, 5, 5, 5)
    pcall(tex.SetTextureSliceMode, tex, Enum.UITextureSliceMode.Stretched)
  end
  tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  tex:SetAllPoints()
  return tex
end

-- A rounded 1px outline on an existing frame (the palette swatches).
function UI.RoundBorder(frame, color, layer)
  if type(frame) ~= "table" then return end
  local c = color or UI.COLOR.edge
  local tex = frame:CreateTexture(nil, layer or "OVERLAY")
  tex:SetTexture(UI.MEDIA.border1)
  if type(tex.SetTextureSliceMargins) == "function" and type(Enum) == "table" and Enum.UITextureSliceMode then
    pcall(tex.SetTextureSliceMargins, tex, 5, 5, 5, 5)
    pcall(tex.SetTextureSliceMode, tex, Enum.UITextureSliceMode.Stretched)
  end
  tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  tex:SetAllPoints()
  return tex
end

-- The selected top tab lifts its native label and upper rim out of the content.
function UI.SkinTabButton(button, label, onClick)
  if type(button) ~= "table" or type(label) ~= "table" then return button end
  button.selectedTextY, button.deselectedTextY = -10, -6
  if not button.uptRaisedTab then
    for _, key in ipairs({ "LeftActive", "MiddleActive", "RightActive" }) do
      local texture = button[key]
      if type(texture) == "table" then texture:SetHeight(texture:GetHeight() + 3) end
    end
    button.uptRaisedTab = true
  end
  if type(onClick) == "function" then button:SetScript("OnClick", onClick) end
  local function paint(selected, hover)
    local C = UI.COLOR
    if selected and type(PanelTemplates_SelectTab) == "function" then PanelTemplates_SelectTab(button)
    elseif not selected and type(PanelTemplates_DeselectTab) == "function" then PanelTemplates_DeselectTab(button) end
    if type(label.SetTextColor) == "function" then
      local color = (selected or hover) and C.text or C.heading
      label:SetTextColor(color[1], color[2], color[3])
    end
  end
  button.tabPaint = paint
  button:HookScript("OnEnter", function() paint(button.tabOn, true) end)
  button:HookScript("OnLeave", function() paint(button.tabOn, false) end)
  paint(false, false)
  return button
end

function UI.TabSelected(button, selected)
  if type(button) ~= "table" or type(button.tabPaint) ~= "function" then return end
  button.tabOn = selected and true or false
  pcall(button.tabPaint, button.tabOn, false)
end

function UI.Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return UI.SkinButton(button)
end

-- Native list rows participate in SettingsPanel's gamepad focus; canvas controls do not.
function UI.RegisterSettingsLauncher(title, tooltip, onClick)
  if type(Settings) ~= "table" or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
      or type(Settings.RegisterInitializer) ~= "function"
      or type(Settings.RegisterAddOnCategory) ~= "function"
      or type(CreateSettingsButtonInitializer) ~= "function" then return false end
  local category = Settings.RegisterVerticalLayoutCategory(title)
  local initializer = CreateSettingsButtonInitializer(title, BIT.L("Open settings"), onClick, tooltip, true)
  Settings.RegisterInitializer(category, initializer)
  Settings.RegisterAddOnCategory(category)
  return true
end

-- A check box with its label to the right. get() and set(value) read and write the setting. The label and the tooltip are
-- English texts (BIT.L translates them); `translated` says the label is shown as it is (it was composed from a template).
function UI.Check(parent, labelText, get, set, tooltip, translated)
  local box = CreateFrame("CheckButton", nil, parent)
  box:SetSize(24, 24)
  box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  UI.SkinCheck(box)
  local shown = translated and labelText or BIT.L(labelText)
  box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
  box.label:SetText(shown)
  if tooltip then
    box:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(shown, 1, 0.82, 0)
      GameTooltip:AddLine(BIT.L(tooltip), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  function box:Refresh() self:SetChecked(get() and true or false) end
  box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  box:Refresh()
  return box
end

-- A slider with its label above and its value to the right. The optional tooltip (the same
-- extra argument UI.Check takes) explains the setting while the label or the slider is hovered.
function UI.Slider(parent, labelText, min, max, step, get, set, format, tooltip)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(260, 40)
  holder.label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  holder.label:SetPoint("TOPLEFT", 0, 0)
  holder.label:SetText(BIT.L(labelText))
  local bar = CreateFrame("Slider", nil, holder)
  bar:SetOrientation("HORIZONTAL")
  bar:SetSize(200, 16)
  bar:SetPoint("TOPLEFT", 0, -18)
  bar:SetMinMaxValues(min, max)
  bar:SetValueStep(step)
  if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
  bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  UI.SkinSlider(bar, 6)
  holder.value = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  holder.value:SetPoint("LEFT", bar, "RIGHT", 8, 0)
  local function show(v) holder.value:SetText(UI.SliderLabel(format, v)) end
  -- The label of a slider value. A format ending in a literal "%" means the value is a fraction
  -- or multiplier: the label shows the percent (0.5 -> 50%). Without a format, whole values stay
  -- plain and fractional values are multipliers, shown with an x (1.25 -> 1.25x). A function
  -- formats the value itself. The stored value is never changed by the label.
  function UI.SliderLabel(format, v)
    if type(format) == "function" then return format(v) end
    if type(format) == "string" then
      if string.find(format, "%%", 1, true) then
        return string.format("%d%%", math.floor(v * 100 + 0.5))
      end
      return string.format(format, v)
    end
    if v == math.floor(v) then return string.format("%d", v) end
    local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    return s .. "x"
  end
  bar:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    show(v)
    if holder.refreshing then return end
    set(v)
  end)
  function holder:Refresh()
    self.refreshing = true
    bar:SetValue(get())
    show(get())
    self.refreshing = false
  end
  holder.bar = bar
  -- Hovering the label or the slider shows the tooltip, so neither spot is dead.
  if tooltip then
    local function enter(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(BIT.L(labelText), 1, 0.82, 0)
      GameTooltip:AddLine(BIT.L(tooltip), 1, 1, 1, true)
      GameTooltip:Show()
    end
    local function leave() GameTooltip:Hide() end
    holder:EnableMouse(true)
    holder:SetScript("OnEnter", enter)
    holder:SetScript("OnLeave", leave)
    bar:SetScript("OnEnter", enter)
    bar:SetScript("OnLeave", leave)
  end
  holder:Refresh()
  return holder
end

---------------------------------------------------------------------------------------------
-- Column layout helpers shared by the module tabs
---------------------------------------------------------------------------------------------

-- A width for a sub-tab button that keeps the art of its neighbours from overlapping (the
-- art needs about 64 px whatever the label is).
UI.TAB_GAP = 4
function UI.TabWidth(text)
  local w = type(text) == "table" and type(text.GetStringWidth) == "function" and text:GetStringWidth() or 48
  if type(w) ~= "number" then w = 48 end
  return math.max(64, math.ceil(w) + 20)
end

-- Grow a row to fit its wrapped label. The label is centred vertically in the row, so a
-- two-line label no longer runs into the rows above and below it.
function UI.FitRow(row, minHeight)
  local label = type(row) == "table" and row.label or nil
  if type(label) ~= "table" or type(label.GetStringHeight) ~= "function" then return end
  local h = label:GetStringHeight()
  if type(h) ~= "number" then return end
  row:SetHeight(math.max(minHeight or 26, math.ceil(h) + 8))
end

-- A section header: small gold caps and a hairline to the column's right edge. It is a frame,
-- so a column can anchor it on both sides and the rule has a right end.
function UI.Header(parent, text)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(20)
  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetPoint("LEFT", 0, 0)
  row.label:SetText(BIT.L(text))
  local heading = UI.COLOR.heading
  row.label:SetTextColor(heading[1], heading[2], heading[3])
  local rule = row:CreateTexture(nil, "ARTWORK")
  local c = UI.COLOR.divider
  rule:SetColorTexture(c[1], c[2], c[3], c[4])
  rule:SetHeight(1)
  rule:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
  rule:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  return row
end

-- A wrapped muted paragraph of a fixed width. Its height is measured, so the next row can be
-- placed below it instead of at a guessed offset.
function UI.Note(parent, text, width)
  local row = CreateFrame("Frame", nil, parent)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.text:SetPoint("TOPLEFT", 0, 0)
  row.text:SetWidth(width)
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(true)
  row.text:SetText(BIT.L(text))
  local h = row.text:GetStringHeight()
  row:SetSize(width, math.max(14, type(h) == "number" and math.ceil(h) or 14))
  return row
end

-- Place a row in a column of its parent, inset 6 on both sides, and return the next y. A check
-- box keeps its own size (its label runs to its right): stretching it across the column would
-- stretch its art and push the label out of view. Every other row spans the column.
function UI.PlaceRow(row, y, height)
  local parent = row:GetParent()
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -y)
  if not (type(row.IsObjectType) == "function" and row:IsObjectType("CheckButton")) then
    row:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
  end
  return y + (height or 26)
end

-- A vertically scrolling column. The holder is what a tab shows and hides; the rows go in
-- holder.content, and holder:Fit(height) sets how tall they are. The slider and the wheel move
-- the same offset, and the slider hides while everything fits.
function UI.ScrollColumn(parent)
  local holder = CreateFrame("Frame", nil, parent)
  local scroll = CreateFrame("ScrollFrame", nil, holder)
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH + 2, 0)
  scroll:EnableMouseWheel(true)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  local bar = CreateFrame("Slider", nil, holder)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(12)
  bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
  UI.SkinSlider(bar, 6, true)

  local function offset()
    local v = scroll:GetVerticalScroll()
    return type(v) == "number" and v or 0
  end
  local function maxScroll()
    return math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
  end
  local function sync()
    local max = maxScroll()
    bar._sync = true
    bar:SetMinMaxValues(0, math.max(max, 0.001))
    bar:SetShown(max > 0)
    if offset() > max then scroll:SetVerticalScroll(max) end
    bar:SetValue(max - math.min(offset(), max))
    bar._sync = false
  end
  scroll:SetScript("OnMouseWheel", function(_, delta)
    scroll:SetVerticalScroll(math.min(math.max(offset() - (delta or 0) * 24, 0), maxScroll()))
    sync()
  end)
  scroll:SetScript("OnSizeChanged", function(_, width)
    if type(width) == "number" and width > 0 then content:SetWidth(width) end
    sync()
  end)
  bar:SetScript("OnValueChanged", function(_, value)
    if bar._sync or type(value) ~= "number" then return end
    local max = maxScroll()
    scroll:SetVerticalScroll(math.min(math.max(max - value, 0), max))
  end)
  holder.scroll, holder.content, holder.bar = scroll, content, bar
  function holder:Fit(height)
    content:SetHeight(math.max(1, height))
    sync()
  end
  return holder
end

---------------------------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------------------------

local function tabSize()
  local w, h = DEFAULT_TAB.width, DEFAULT_TAB.height
  for _, name in ipairs(BIT.order) do
    local tab = BIT.tabs[name]
    if tab then
      w = math.max(w, tab.width or 0)
      h = math.max(h, tab.height or 0)
    end
  end
  h = math.min(h, MAX_CONTENT_HEIGHT)
  return w, h
end

local STATE_TEXT = {
  on = "Running.",
  off = "Switched off.",
}

local function stateText(name)
  local state = BIT.state[name]
  local wanted = BIT.IsSwitchedOn(name)
  if (state == "on") ~= wanted then
    return BIT.L(wanted and "Switched on after a reload of the interface." or "Switched off after a reload of the interface.")
  end
  return STATE_TEXT[state] and BIT.L(STATE_TEXT[state]) or ""
end

local function refreshSwitch(page)
  if not page.switch then return end
  page.switch:Refresh()
  page.stateLine:SetText(stateText(page.name))
  local pending = (BIT.state[page.name] == "on") ~= BIT.IsSwitchedOn(page.name)
  page.reload:SetShown(pending)
end

local function playerClass()
  if type(UnitClass) ~= "function" then return nil end
  return select(2, UnitClass("player"))
end

local function tabTextColor(name, on)
  local irrelevant = name == "HunterRangeFinder" and playerClass() ~= "HUNTER"
  if on then
    if irrelevant then return 0.62, 0.62, 0.48 end
    return 1, 1, 1
  end
  if irrelevant then return 0.42, 0.42, 0.38 end
  return UI.COLOR.heading[1], UI.COLOR.heading[2], UI.COLOR.heading[3]
end

-- A vertical slider on the scroll frame's right. The thumb at the top is the start of the
-- content (WoW's vertical slider keeps its minimum at the bottom, so the value is inverted).
-- Hidden while the content fits. Mouse wheel and the slider move the same offset.
local function attachScroll(page, topOffset)
  local scroll = CreateFrame("ScrollFrame", nil, page)
  scroll:SetPoint("TOPLEFT", 0, -topOffset)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 0)
  scroll:EnableMouseWheel(true)
  local content = CreateFrame("Frame", nil, scroll)
  local function contentWidth()
    local w = 0
    if type(scroll.GetWidth) == "function" then w = scroll:GetWidth() or 0 end
    if type(w) ~= "number" or w <= 1 then
      w = (window:GetWidth() or 200) - 2 * MARGIN - SCROLL_BAR_WIDTH
    end
    return math.max(1, w)
  end
  content:SetWidth(contentWidth())
  scroll:SetScrollChild(content)

  local bar = CreateFrame("Slider", nil, page)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(12)
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 0)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  if type(bar.SetThumbTexture) == "function" then
    bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
  end
  UI.SkinSlider(bar, 6, true)

  local function scrollOffset()
    if type(scroll.GetVerticalScroll) ~= "function" then return 0 end
    local v = scroll:GetVerticalScroll()
    if type(v) ~= "number" then return 0 end
    return v
  end
  local function maxScroll()
    return math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
  end
  local function syncBar()
    local max = maxScroll()
    bar._sync = true
    bar:SetMinMaxValues(0, math.max(max, 0.001))
    if max <= 0 then bar:Hide() else bar:Show() end
    if scrollOffset() > max and type(scroll.SetVerticalScroll) == "function" then
      scroll:SetVerticalScroll(max)
    end
    bar:SetValue(max - math.min(scrollOffset(), max))
    bar._sync = false
  end
  local function setScroll(at)
    local max = maxScroll()
    at = math.min(math.max(at or 0, 0), max)
    if type(scroll.SetVerticalScroll) == "function" then scroll:SetVerticalScroll(at) end
    syncBar()
  end
  scroll:SetScript("OnMouseWheel", function(_, delta)
    setScroll(scrollOffset() - (delta or 0) * 24)
  end)
  content:SetScript("OnSizeChanged", function() syncBar() end)
  scroll:SetScript("OnSizeChanged", function(_, width)
    if type(width) == "number" and width > 0 then content:SetWidth(width) end
    syncBar()
  end)
  bar:SetScript("OnValueChanged", function(_, value)
    if bar._sync or type(value) ~= "number" then return end
    local max = maxScroll()
    if type(scroll.SetVerticalScroll) == "function" then
      scroll:SetVerticalScroll(math.min(math.max(max - value, 0), max))
    end
  end)
  page.scroll, page.content, page.scrollBar = scroll, content, bar
  page.syncScroll = syncBar
  return content
end

local function headerBottom()
  return HEADER_HEIGHT + TAB_HEIGHT * tabRows
end

-- Anchor points a saved window position may name; anything else (or a non-finite offset)
-- must never reach Frame:SetPoint -- a corrupt shared SavedVariables would break /upt.
local WINDOW_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
  RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

local function savedWindowPoint()
  if type(BIT.DB) ~= "function" then return nil end
  local saved = BIT.DB()
  local p = type(saved) == "table" and saved.window or nil
  if type(p) ~= "table" or type(p.point) ~= "string" or not WINDOW_POINTS[p.point] then return nil end
  if type(p.x) ~= "number" or type(p.y) ~= "number" then return nil end
  if p.x ~= p.x or p.y ~= p.y or p.x == math.huge or p.x == -math.huge
      or p.y == math.huge or p.y == -math.huge then return nil end
  if type(p.relativePoint) == "string" and not WINDOW_POINTS[p.relativePoint] then p.relativePoint = nil end
  return p
end

local function applyWindowPoint()
  window:ClearAllPoints()
  local p = savedWindowPoint()
  if not p then
    window:SetPoint("CENTER")
    return
  end
  window:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x, p.y)
end

local function rememberWindowPoint()
  if type(window.GetPoint) ~= "function" then return end
  local point, _, relativePoint, x, y = window:GetPoint(1)
  if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
  if type(BIT.DB) ~= "function" then return end
  BIT.DB().window = {
    point = point,
    relativePoint = type(relativePoint) == "string" and relativePoint or point,
    x = x,
    y = y,
  }
end

local selectTab

local MODULE_STORES = {
  SpellDamageInfo = "Ready2QuestCombat_SpellDamageInfoDB",
  DoTInfo = "Ready2QuestCombat_DoTInfoDB",
  ResourceDing = "Ready2QuestCombat_ResourceDingDB",
}

local function copyDefault(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[key] = copyDefault(entry) end
  return copy
end

local function resetModule(name)
  local tab, module = BIT.tabs[name], BIT.modules[name]
  local defaults = tab and (tab.defaults or (module and (module.DEFAULTS or module.defaults)))
  if type(defaults) ~= "table" then
    BIT.Say(string.format(BIT.L("Cannot reset %s: defaults are unavailable."), name))
    return
  end
  if type(ReloadUI) ~= "function" then
    BIT.Say(BIT.L("Cannot reset settings: reloading the interface is unavailable."))
    return
  end
  local storeName = MODULE_STORES[name]
  local store
  if storeName then store = _G[storeName] else store = BIT.DB().modules[name] end
  if store ~= nil and type(store) ~= "table" then
    BIT.Say(string.format(BIT.L("Cannot reset %s: its settings are invalid."), name))
    return
  end
  if store == nil then
    store = {}
    if storeName then _G[storeName] = store else BIT.DB().modules[name] = store end
  end
  if BIT.Style and BIT.Style.Reset then
    local ok, err = pcall(BIT.Style.Reset, name)
    if not ok then
      BIT.Say(string.format(BIT.L("Cannot reset %s appearance: %s"), name, tostring(err)))
      return
    end
  end
  for key, value in pairs(defaults) do store[key] = copyDefault(value) end
  if name == "ResourceDing" then
    store.manaLevels, store.manaPercent = nil, nil
  elseif name == "CastPrediction" then
    store.talentForce, store.auraForce = {}, {}
  elseif name == "HunterRangeFinder" then
    store.plateScheme = 2
  end
  ReloadUI()
end

local function confirmResetModule(name)
  StaticPopupDialogs["UPT_RESET_MODULE"] = {
    text = BIT.L("Reset all settings for %s? The interface will reload. Module enable state, learned data and shared settings are kept."),
    button1 = BIT.L("Reset module"), button2 = CANCEL,
    OnAccept = function(_, moduleName) resetModule(moduleName) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  local tab = BIT.tabs[name]
  StaticPopup_Show("UPT_RESET_MODULE", BIT.L(tab.title or name), nil, name)
end

local function buildPage(name)
  local tab = BIT.tabs[name] or {}
  local page = CreateFrame("Frame", nil, window)
  page:SetPoint("TOPLEFT", MARGIN, -headerBottom())
  page:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + (window.gamepadPadding or 0))
  page:Hide()
  page.name = name

  -- A plain tab (Debug) is a tool page, not a part: no Enable box, and it is always built.
  if not tab.plain then
  page.switch = UI.Check(page, string.format(BIT.L("Enable %s"), BIT.L(tab.title or name)),
    function() return BIT.IsSwitchedOn(name) end,
    function(v)
      BIT.SetSwitchedOn(name, v)
      -- Still running: the page stays, and only the pending-reload line changes.
      -- Ticked on while off: wake defaults and build the real settings.
      -- Ticked off while not running: back to the off note. Gameplay waits for /reload.
      if BIT.IsRunning(name) then
        refreshSwitch(page)
        return
      end
      if v then
        BIT.Wake(name)
      elseif BIT.woke then
        BIT.woke[name] = nil
      end
      page:Hide()
      pages[name], parkedPages[name] = parkedPages[name], page
      selectTab(name)
    end, tab.summary, true)
  page.switch:SetPoint("TOPLEFT", 4, -6)
  page.stateLine = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  page.stateLine:SetPoint("TOPLEFT", 32, -30)
  page.stateLine:SetPoint("TOPRIGHT", -120, -30)
  page.stateLine:SetHeight(16)
  page.stateLine:SetJustifyH("LEFT")
  page.reload = UI.Button(page, BIT.L("Reload UI"), 100, function()
    if type(ReloadUI) == "function" then ReloadUI() end
  end)
  page.reload:SetPoint("TOPRIGHT", -4, -7)
  page.resetModule = UI.Button(page, BIT.L("Reset module"), 140, function() confirmResetModule(name) end)
  page.resetModule:SetPoint("RIGHT", page.reload, "LEFT", -8, 0)
  end

  local content = attachScroll(page, tab.plain and 0 or SWITCH_HEIGHT)

  local viewport = page.scroll:GetHeight()
  local function layoutContent()
    local needed = math.max(tab.height or DEFAULT_TAB.height, page.offNote and 0 or content:GetHeight())
    if page.appearance then
      needed = math.max(needed, 74 + page.appearance:GetHeight())
    end
    content:SetHeight(math.max(needed, viewport))
    if page.syncScroll then page.syncScroll() end
  end

  local showLive = (tab.plain or BIT.IsRunning(name) or (BIT.woke and BIT.woke[name])) and type(tab.build) == "function"
  if showLive then
    content:SetHeight(tab.height or DEFAULT_TAB.height)
    local ok, err = pcall(tab.build, content)
    if not ok then
      BIT.Say("the " .. name .. " settings could not be built: " .. tostring(err))
    end
  else
    local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", 8, -8)
    note:SetPoint("RIGHT", -8, 0)
    note:SetJustifyH("LEFT")
    note:SetText((tab.summary and (BIT.L(tab.summary) .. "\n\n") or "")
      .. BIT.L("Its settings are here while it runs; its appearance and a sample preview are below"
      .. " -- they need no module runtime. Tick Enable to open the settings before the next reload."))
    page.offNote = note
    page.appearance = BIT.UI.Appearance(content, name, tab.capabilities, function()
      if page.layoutOffPage then page.layoutOffPage() end
    end, tab.legacy)
    local function layoutOffPage()
      local top = math.max(74, (note:GetStringHeight() or 54) + 20)
      page.appearance:SetPoint("TOPLEFT", 8, -top)
      content:SetHeight(math.max(viewport, top + page.appearance:GetHeight() + 12))
      if page.syncScroll then page.syncScroll() end
    end
    page.appearance.onLayout = layoutOffPage
    page.layoutOffPage = layoutOffPage
    layoutOffPage()
  end

  if page.layoutOffPage then page.layoutOffPage() else layoutContent() end
  refreshSwitch(page)
  return page
end

selectTab = function(name)
  if not pages[name] then pages[name] = buildPage(name) end
  for n, page in pairs(pages) do page:SetShown(n == name) end
  for _, button in ipairs(tabButtons) do
    local on = button.name == name
    local r, g, b = tabTextColor(button.name, on)
    UI.TabSelected(button, on)
    button.text:SetTextColor(r, g, b)
  end
  current = name
  if BIT.GamePadUI then BIT.GamePadUI.Clear() end
  local page = pages[name]
  refreshSwitch(page)
  if type(window.refreshGamePadHints) == "function" then window.refreshGamePadHints() end
end

local function addTabButton(name, label, tipTitle, tipBody, extraTip)
  local button = CreateFrame("Button", nil, window, "PanelTopTabButtonTemplate")
  button.name = name
  button:SetText(label)
  button.text = button:GetFontString()
  local width = UI.TabWidth(button.text)
  button:SetSize(width, TAB_HEIGHT - 2)
  button:SetScript("OnClick", function() selectTab(name) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tipTitle or label, 1, 0.82, 0)
    if tipBody and tipBody ~= "" then GameTooltip:AddLine(tipBody, 1, 1, 1, true) end
    if extraTip then GameTooltip:AddLine(extraTip, 0.8, 0.8, 0.6, true) end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UI.SkinTabButton(button, button.text)
  tabButtons[#tabButtons + 1] = button
  return button
end

local function layoutTabs()
  local maxW = (window:GetWidth() or 400) - MARGIN
  local x = MARGIN
  local row = 0
  for _, button in ipairs(tabButtons) do
    local width = button:GetWidth() or 64
    if x > MARGIN and x + width > maxW then
      x = MARGIN
      row = row + 1
    end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", x, -(HEADER_HEIGHT + row * TAB_HEIGHT))
    x = x + width + 4
  end
  tabRows = row + 1
end

local function createWindow()
  local w, h = tabSize()
  window = CreateFrame("Frame", "Ready2QuestCombatSettings", UIParent, "ButtonFrameTemplate")
  if type(ButtonFrameTemplate_HidePortrait) == "function" then ButtonFrameTemplate_HidePortrait(window) end
  if type(window.Inset) == "table" then window.Inset:Hide() end
  window:Hide()
  window:SetSize(w + 2 * MARGIN, HEADER_HEIGHT + TAB_HEIGHT + SWITCH_HEIGHT + h + MARGIN)
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", function(self)
    if type(self.StopMovingOrSizing) == "function" then self:StopMovingOrSizing() end
    rememberWindowPoint()
  end)
  applyWindowPoint()
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "Ready2QuestCombatSettings") end

  window:SetTitle("Ready2Quest Combat")
  local close = window.CloseButton
  if type(close) ~= "table" then
    close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
  end
  close:SetScript("OnClick", function() window:Hide() end)

  for _, name in ipairs(BIT.order) do
    local tab = BIT.tabs[name] or {}
    local extra
    if name == "HunterRangeFinder" and playerClass() ~= "HUNTER" then
      extra = BIT.L("Hunter only. Settings are here for an alt.")
    end
    addTabButton(name, BIT.L(SHORT_LABEL[name] or tab.title or name), BIT.L(tab.title or name), BIT.L(tab.summary), extra)
  end
  layoutTabs()
  window.baseHeight = HEADER_HEIGHT + TAB_HEIGHT * tabRows + SWITCH_HEIGHT + h + MARGIN
  -- The gamepad hint line below the pages adds to the window instead of taking from the pages,
  -- so a controller does not cut the bottom of every tab.
  window.fit = function(extra)
    window:SetHeight(window.baseHeight + (extra or 0))
    window:SetScale(math.min(1, (UIParent:GetWidth() - 24) / window:GetWidth(),
      (UIParent:GetHeight() - 24) / window:GetHeight()))
  end
  window.fit(0)

  if BIT.GamePadUI then
    local pad = BIT.GamePadUI
    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 3)
    hint:SetPoint("BOTTOMRIGHT", -12, 3)
    hint:SetJustifyH("LEFT")
    local function refreshHints()
      local enabled = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
        or GetCVarBool and GetCVarBool("GamePadEnable")
      hint:SetText(enabled and (pad.Hint() .. " · " .. string.format(BIT.L("%s/%s: tabs"),
        pad.Key("PADLSHOULDER"), pad.Key("PADRSHOULDER"))) or "")
      hint:SetWordWrap(true)
      local padding = enabled and math.max(32, hint:GetStringHeight() + 8) or 0
      window.gamepadPadding = padding
      window.fit(padding)
      for _, page in pairs(pages) do page:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + padding) end
    end
    window.refreshGamePadHints = refreshHints
    local events = CreateFrame("Frame", nil, window)
    for _, event in ipairs({ "UPDATE_BINDINGS", "CVAR_UPDATE", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONFIGS_CHANGED" }) do
      pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", refreshHints)
    window:HookScript("OnShow", refreshHints)
    pad.Attach(window, function(self, key)
      if key == "PAD2" then self:Hide(); return true end
      if key == "PADLSHOULDER" or key == "PADRSHOULDER" then
        local index = 1
        for i, name in ipairs(BIT.order) do if name == current then index = i end end
        selectTab(BIT.order[(index - 1 + (key == "PADLSHOULDER" and -1 or 1)) % #BIT.order + 1])
        return true
      end
      return pad.Navigate(self, key)
    end)
  end

  window:HookScript("OnShow", function()
    if current and pages[current] then
      refreshSwitch(pages[current])
    end
  end)
end

-- Opens the window, on a module's tab when name is given; a second call without a name closes it.
-- A second call with the SAME tab name closes it too (the README's "type it again to hide").
function BIT.OpenSettings(name)
  if not window then createWindow() end
  if name and BIT.tabs[name] then
    if window:IsShown() and current == name then
      window:Hide()
      return
    end
    selectTab(name)
    window:Show()
    return
  end
  if window:IsShown() then
    window:Hide()
    return
  end
  selectTab(current or BIT.order[1])
  window:Show()
end

---------------------------------------------------------------------------------------------
-- /upt, and a page in Options > AddOns
---------------------------------------------------------------------------------------------

BIT.commands = {} -- word -> function(rest), from the modules (/upt probe)

function BIT.RegisterCommand(word, fn) BIT.commands[word] = fn end

BINDING_HEADER_R2QCOMBAT = "Ready2Quest Combat"
BINDING_NAME_R2QCOMBAT_SETTINGS = "Open settings"
function Ready2QuestCombat_ToggleSettings() BIT.OpenSettings() end

-- Short names for the tabs: /upt sdi, /upt did, /upt stats, /upt ding, /upt range
BIT.tabWords = {}

local function slash(msg)
  msg = type(msg) == "string" and msg or ""
  local word, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
  word = (word or ""):lower()
  if word == "" then BIT.OpenSettings() return end
  if BIT.commands[word] then BIT.commands[word](rest) return end
  for _, name in ipairs(BIT.order) do
    if word == name:lower() or BIT.tabWords[word] == name then BIT.OpenSettings(name) return end
  end
  BIT.Say(string.format(BIT.L("/upt opens the settings; /upt <part> opens a part's tab (%s); /upt probe records what StatsInfo can read; /upt lang sets the language."),
    table.concat(BIT.order, ", ")))
end

SLASH_R2QCOMBAT1 = "/r2qc"
SLASH_R2QCOMBAT2 = "/r2qcombat"
if type(SlashCmdList) == "table" then SlashCmdList.R2QCOMBAT = slash end

local function registerOptionsPage()
  local function openSettings()
    -- Keep Blizzard's panel open so its native gamepad binding teardown stays native.
    if not (window and window:IsShown()) then BIT.OpenSettings() end
  end
  if UI.RegisterSettingsLauncher("Ready2Quest Combat",
      BIT.L("Open the settings window. You can also type /upt."), openSettings) then return end
  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Ready2Quest Combat")
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  text:SetText(BIT.L("The settings have their own window. You can also type /upt."))
  local open = UI.Button(panel, BIT.L("Open settings"), 180, openSettings)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
  if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function"
    and type(Settings.RegisterAddOnCategory) == "function" then
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "Ready2Quest Combat"))
  elseif type(InterfaceOptions_AddCategory) == "function" then
    panel.name = "Ready2Quest Combat"
    InterfaceOptions_AddCategory(panel)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
  BINDING_NAME_R2QCOMBAT_SETTINGS = BIT.L("Open settings") -- the saved language is known only from ADDON_LOADED on
  local ok, err = pcall(registerOptionsPage)
  if not ok then BIT.Say("Options > AddOns page not added (" .. tostring(err) .. "); /upt still opens the settings.") end
  self:UnregisterAllEvents()
end)
