-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: custom frames. Lets the marks that sit on a unit frame's health bar (DoTInfo, ShieldsInfo,
-- HealPrediction) attach to another addon's frame instead of Blizzard's, which unit frame replacements hide.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
-- Adapted from Does It Die's Frames.lua (Joe Greive, MIT); see Modules/DoTInfo/LICENSE-DoesItDie.txt.
--
-- A setting holds a frame path: a global frame name, optionally followed by keys, e.g. "ElvUF_Target.Health". The
-- Pick button (or /upt pick) fills one in from the frame under the mouse. The marks only need the health bar's
-- rectangle (they are laid over it, filling left to right on the same max-health scale), so any bar that fills
-- left to right and whose frame is exactly the fill area works. Empty settings change nothing.
--
--   /upt frame                      shows the paths in use
--   /upt frame target|icon|focus|player|plate <path>     sets one ("clear" removes it)
--   /upt pick target|icon|focus|player                   click the frame on screen
local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Frames = {}
BIT.Frames = Frames

local KEYS = { target = true, icon = true, focus = true, player = true, plate = true }
Frames.KEYS = KEYS

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, r = pcall(issecretvalue, v)
  return ok and r or false
end

-- A plain value from region:method(), or nil if it errors or is secret.
local function plain(region, method, ...)
  local fn = type(region) == "table" and region[method]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, region, ...)
  if not ok or isSecret(value) then return nil end
  return value
end

-- The saved path of a key ("" when none).
function Frames.Get(key)
  if not KEYS[key] or type(BIT.DB) ~= "function" then return "" end
  local saved = BIT.DB()
  local paths = type(saved) == "table" and saved.frames
  local path = type(paths) == "table" and paths[key]
  if type(path) ~= "string" then return "" end
  return strtrim(path)
end

function Frames.Set(key, path)
  if not KEYS[key] or type(BIT.DB) ~= "function" then return end
  local saved = BIT.DB()
  if type(saved.frames) ~= "table" then saved.frames = {} end
  saved.frames[key] = strtrim(path or "")
end

-- Frame path -> the frame (or texture), or nil if it does not exist (yet: some addons build frames late).
function Frames.Resolve(path)
  if type(path) ~= "string" then return nil end
  path = strtrim(path)
  if path == "" then return nil end
  local ok, object = pcall(function()
    local object, first = nil, true
    for part in path:gmatch("[^%.]+") do
      if first then
        object = _G[part]
        first = false
      elseif type(object) == "table" then
        object = object[part]
      else
        return nil
      end
      if object == nil then return nil end
    end
    return object
  end)
  if ok and type(object) == "table" and type(object.GetObjectType) == "function"
    and type(object.GetWidth) == "function" then
    return object
  end
end

-- From a Blizzard nameplate down to a plate addon's bar: keys only, e.g. "unitFrame.healthBar".
function Frames.ResolveFromPlate(plate, path)
  if type(plate) ~= "table" or type(path) ~= "string" or strtrim(path) == "" then return nil end
  local current = plate
  for key in string.gmatch(path, "[^%.]+") do
    local ok, value = pcall(function() return current[key] end)
    if not ok or type(value) ~= "table" then return nil end
    current = value
  end
  if current ~= plate and plain(current, "GetObjectType") == "StatusBar" then return current end
end

-- The key under which `parent` holds `region`, if it is a plain identifier.
local function keyInParent(region, parent)
  local key = plain(region, "GetParentKey")
  if type(key) == "string" and parent[key] == region then return key end
  for k, v in pairs(parent) do
    if v == region and type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
  end
end

-- The global name of `frame`, or nil.
local function globalName(frame)
  local name = plain(frame, "GetName")
  if type(name) == "string" and not name:find(".", 1, true) and _G[name] == frame then return name end
end

-- A path that finds `region` again after a reload, or nil if it has no named ancestor to start from.
-- The path is checked: it must resolve to `region` itself.
function Frames.PathOf(region)
  local parts, current = {}, region
  for _ = 1, 12 do
    local name = globalName(current)
    if name then
      table.insert(parts, 1, name)
      local path = table.concat(parts, ".")
      return Frames.Resolve(path) == region and path or nil
    end
    local parent = plain(current, "GetParent")
    if not parent then break end
    local keyOK, key = pcall(keyInParent, current, parent)
    if not keyOK or not key then break end
    table.insert(parts, 1, key)
    current = parent
  end
  -- A unit frame addon may move the bar into an unnamed holder (EllesmereUI's clip frame) and still keep it as a
  -- field of its named frame. Look for the bar among the fields of each named ancestor. The fields of other
  -- addons' frames are read under pcall (an __index may raise), and the lowest key wins so that the saved path
  -- is the same in every session.
  local ancestor = plain(region, "GetParent")
  for _ = 1, 12 do
    if not ancestor then return nil end
    local name = globalName(ancestor)
    if name then
      local ok, keys = pcall(function()
        local found = {}
        for k, v in pairs(ancestor) do
          if v == region and type(k) == "string" and k:match("^[%a_][%w_]*$") then found[#found + 1] = k end
        end
        table.sort(found)
        return found
      end)
      if ok and keys[1] then
        local path = name .. "." .. keys[1]
        if Frames.Resolve(path) == region then return path end
      end
    end
    ancestor = plain(ancestor, "GetParent")
  end
end

-- Stop at the owning unit frame for layering; shared UI roots include unrelated frames.
-- Without a unit, retain the top-level ancestor for the frame picker.
function Frames.Root(region, unit)
  local current = region
  for _ = 1, 20 do
    if unit and plain(current, "GetAttribute", "unit") == unit then return current end
    local parent = plain(current, "GetParent")
    if not parent or parent == UIParent then return current end
    current = parent
  end
  return current
end

-- Whether a custom bar is on screen: a replacement frame that is hidden hides the marks with it.
function Frames.Shown(bar)
  if plain(bar, "IsForbidden") == true then return false end
  if plain(bar, "IsVisible") == false then return false end
  local alpha = plain(bar, "GetEffectiveAlpha")
  return type(alpha) ~= "number" or alpha > 0
end

---------------------------------------------------------------------------------------------
-- Pick mode
---------------------------------------------------------------------------------------------

-- Health bars usually do not take the mouse themselves (the unit button around them does), so the mouse focus
-- only says which frame the cursor is on. Pick searches that frame's whole top-level frame for what is under
-- the cursor and takes the smallest match: a StatusBar for "bar", any frame or texture for "anchor".
local MIN_ANCHOR_SIZE = 12
local picker -- { kind, onPick, candidate }
local pickFrame, highlight, pickLabel

local function mouseFocus()
  if GetMouseFoci then
    local foci = GetMouseFoci()
    return foci and foci[1]
  end
  if GetMouseFocus then return GetMouseFocus() end
end

-- The region's rectangle in its own coordinates, or nil if it has none or any part of it is secret.
local function plainRect(region)
  local ok, left, bottom, width, height = pcall(region.GetRect, region)
  if not ok or type(left) ~= "number" then return nil end
  for _, v in ipairs({ left, bottom, width, height }) do
    if isSecret(v) or type(v) ~= "number" then return nil end
  end
  return left, bottom, width, height
end

-- Width and height of a visible region under the cursor, else nil. IsMouseOver is secret on some of Blizzard's
-- frames; then the cursor is checked against the rectangle, if that is readable.
local function areaUnderMouse(region)
  if plain(region, "IsVisible") ~= true then return nil end
  local left, bottom, width, height = plainRect(region)
  if not left then return nil end
  local over = plain(region, "IsMouseOver")
  if over == nil then
    local scale = plain(region, "GetEffectiveScale")
    if type(scale) ~= "number" or scale <= 0 then return nil end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    over = x >= left and x <= left + width and y >= bottom and y <= bottom + height
  end
  if not over then return nil end
  return width, height
end

local function findCandidate(kind)
  local focus = mouseFocus()
  if not focus or focus == WorldFrame or focus == pickFrame then return nil end
  local root = Frames.Root(focus)
  local best, bestArea
  local function consider(region, isBar)
    if kind == "bar" and not isBar then return end
    local width, height = areaUnderMouse(region)
    if not width then return end
    if kind == "anchor" and (width < MIN_ANCHOR_SIZE or height < MIN_ANCHOR_SIZE) then return end
    local area = width * height
    if not bestArea or area < bestArea then best, bestArea = region, area end
  end
  local function visit(frame, depth)
    consider(frame, plain(frame, "GetObjectType") == "StatusBar")
    if kind == "anchor" then
      for _, region in ipairs({ frame:GetRegions() }) do
        if plain(region, "GetObjectType") == "Texture" then consider(region, false) end
      end
    end
    if depth < 8 then
      for _, child in ipairs({ frame:GetChildren() }) do visit(child, depth + 1) end
    end
  end
  visit(root, 0)
  return best
end

function Frames.StopPick()
  picker = nil
  if pickFrame then pickFrame:Hide() end
end

local function createPickFrame()
  pickFrame = CreateFrame("Frame", nil, UIParent)
  pickFrame:SetFrameStrata("TOOLTIP")
  pickFrame:Hide()

  highlight = CreateFrame("Frame", nil, pickFrame)
  highlight:SetFrameStrata("TOOLTIP")
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local edge = highlight:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(0.2, 1, 0.3, 1)
    if side == "TOP" or side == "BOTTOM" then
      edge:SetHeight(2)
      edge:SetPoint(side .. "LEFT")
      edge:SetPoint(side .. "RIGHT")
    else
      edge:SetWidth(2)
      edge:SetPoint("TOP" .. side)
      edge:SetPoint("BOTTOM" .. side)
    end
  end
  local fill = highlight:CreateTexture(nil, "ARTWORK")
  fill:SetAllPoints()
  fill:SetColorTexture(0.2, 1, 0.3, 0.15)

  pickLabel = pickFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  pickLabel:SetPoint("TOP", UIParent, "TOP", 0, -120)

  local function update()
    local candidate = findCandidate(picker.kind)
    picker.candidate = candidate
    highlight:ClearAllPoints()
    if candidate then
      highlight:SetAllPoints(candidate)
      highlight:Show()
    else
      highlight:Hide()
    end
    local what = picker.kind == "bar" and BIT.L("the health bar") or BIT.L("where the kill icon should go")
    local text = candidate and (Frames.PathOf(candidate) or BIT.L("(this frame has no name to save)"))
      or BIT.L("nothing under the mouse")
    pickLabel:SetText(string.format(BIT.L("DoesItDiePlus: click %s (right-click to cancel)"), what)
      .. "\n|cff33ff4d" .. text .. "|r")
  end

  -- Runs 20 times a second over frames we do not own: an error stops picking (reported once) instead of repeating.
  local sinceCheck = 0
  pickFrame:SetScript("OnUpdate", function(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if not picker or sinceCheck < 0.05 then return end
    sinceCheck = 0
    local ok, err = pcall(update)
    if not ok then
      Frames.StopPick()
      BIT.Say(string.format(BIT.L("Frame pick stopped after an error: %s. You can still type a frame name."), tostring(err)))
    end
  end)

  -- The click that picks. (GLOBAL_MOUSE_DOWN may not exist on every client; a path can be typed instead.)
  pcall(pickFrame.RegisterEvent, pickFrame, "GLOBAL_MOUSE_DOWN")
  pickFrame:SetScript("OnEvent", function(_, _, button)
    if not picker then return end
    local current = picker
    Frames.StopPick()
    if button == "RightButton" then
      BIT.Say(BIT.L("Frame pick cancelled."))
      return
    end
    if not current.candidate then
      BIT.Say(BIT.L("Nothing to pick there."))
      return
    end
    local path = Frames.PathOf(current.candidate)
    if not path then
      BIT.Say(BIT.L("That frame has no name to save, so it cannot be found again after a reload. Try the frame around it, or type a path."))
      return
    end
    current.onPick(path)
  end)
end

-- kind: "bar" or "anchor". onPick(path) runs when a saveable frame is clicked. (The Pick button's own click
-- cannot count: its mouse-down came before this.)
function Frames.StartPick(kind, onPick)
  if not pickFrame then createPickFrame() end
  picker = { kind = kind, onPick = onPick }
  pickFrame:Show()
end

---------------------------------------------------------------------------------------------
-- /upt frame, /upt pick
---------------------------------------------------------------------------------------------

local function describe(key)
  local path = Frames.Get(key)
  if path == "" then return BIT.L("automatic") end
  if key == "plate" then return path end
  return Frames.Resolve(path) and ("|cff66ff66" .. path .. "|r")
    or ("|cffff6666" .. string.format(BIT.L("%s not found"), path) .. "|r")
end

if BIT.RegisterCommand then
  BIT.RegisterCommand("frame", function(rest)
    local key, path = (rest or ""):match("^(%S*)%s*(.-)%s*$")
    key = (key or ""):lower()
    if KEYS[key] and path ~= "" then
      if path:lower() == "clear" then path = "" end
      Frames.Set(key, path)
      BIT.Say(string.format("%s: %s", key, describe(key)))
      return
    end
    for _, k in ipairs({ "target", "icon", "focus", "player", "plate" }) do
      BIT.Say(string.format("%s: %s", k, describe(k)))
    end
    BIT.Say(BIT.L("/upt frame target|icon|focus|player|plate <path> sets one (\"clear\" removes it); /upt pick target|icon|focus|player"))
  end)
  BIT.RegisterCommand("pick", function(rest)
    local key = ((rest or ""):match("^(%S+)") or ""):lower()
    if not KEYS[key] or key == "plate" then
      BIT.Say(BIT.L("/upt pick target|icon|focus|player, then click the frame on screen (right-click cancels)."))
      return
    end
    BIT.Say(key == "icon" and BIT.L("Click the spot for the kill icon. Right-click cancels.")
      or string.format(BIT.L("Click the health bar of %s. Right-click cancels."), key))
    Frames.StartPick(key == "icon" and "anchor" or "bar", function(path)
      Frames.Set(key, path)
      BIT.Say(string.format(BIT.L("Picked %s for %s."), path, key))
    end)
  end)
end
