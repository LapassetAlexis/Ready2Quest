-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: one owner for the marks that share a nameplate.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The live seat, for the hunter rail and for ResourceDing's dots and diamonds, is
-- SetPoint("TOP", healthBar, "BOTTOM", 0, -offset). Positive offset moves the widget down.
-- In that frame (positive y up, origin on the health bar's bottom edge) the widget's top is
-- at y = -offset and its body occupies [top - height, top]. The previews use the same seat.
-- Range's check sits above the bar (BOTTOM to TOP) and is not part of this span.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Plate = {}
BIT.Plate = Plate

-- Body heights of the live widgets. The hunter rail is the row of dots plus its icons;
-- the resource rows are one dot tall (ResourceDing's default dot size).
Plate.HUNTER_RAIL_HEIGHT = 16
Plate.DOT_ROW_HEIGHT = 14
Plate.SHARD_ROW_HEIGHT = 14
Plate.SHIELD_EDGE = 4

local function read(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, value = pcall(fn, ...)
  if ok and not (type(issecretvalue) == "function" and issecretvalue(value)) then return value end
end

-- The frame family of each unit, for EUI's global ("EllesmereUIUnitFrames_Focus") and Blizzard's
-- ("FocusFrameHealthBar"); any other unit is the target's. Blizzard's focus frame is built from the target
-- frame's template, so its bar and portrait sit at the target frame's paths.
local FRAME_PART = { player = "Player", focus = "Focus" }

-- Hooks for other addons' frames (Core/Integrations/*.lua): each source returns what it finds, or nothing.
--   Plate.RegisterUnitFrameSource(function(unit, part) return host, bar, portrait end)
--   Plate.RegisterPlateBarSource(function(plate) return bar, path end)
Plate.unitFrameSources, Plate.plateBarSources = {}, {}
function Plate.RegisterUnitFrameSource(fn) Plate.unitFrameSources[#Plate.unitFrameSources + 1] = fn end
function Plate.RegisterPlateBarSource(fn) Plate.plateBarSources[#Plate.plateBarSources + 1] = fn end

-- EUI keeps Blizzard's frames alive but hidden, so follow the profile's active source.
local function unitFrameBase(unit)
  local part = FRAME_PART[unit] or "Target"
  -- A frame the player named (Core/Frames.lua: /upt frame, DoTInfo > Behavior) comes before everything else.
  local Frames = BIT.Frames
  if Frames then
    local key = FRAME_PART[unit] and string.lower(FRAME_PART[unit]) or "target"
    local path = Frames.Get(key)
    if path ~= "" then
      local bar = Frames.Resolve(path)
      if bar then
        -- A replacement frame that is hidden (no target, switched off) hides the marks with it.
        if not Frames.Shown(bar) then return end
        return Frames.Root(bar, unit), bar, nil
      end
    end
  end
  -- Enhance QoL's unit frames hard-hide Blizzard's (reparented under a hidden frame, flagged _eqolUFHidden) and draw
  -- their own: EQOLUF<Part>Frame with the bar EQOLUF<Part>Health. Marks go on that bar; while its frame is not
  -- shown (no target) there is nothing to mark, and Blizzard's hidden bar must not get them.
  local blizzard = (unit == "player" and PlayerFrame) or (unit == "focus" and FocusFrame) or (unit ~= "player" and unit ~= "focus" and TargetFrame)
  if type(blizzard) == "table" and read(function() return blizzard._eqolUFHidden end) == true then
    local frame, bar = _G["EQOLUF" .. part .. "Frame"], _G["EQOLUF" .. part .. "Health"]
    if type(frame) ~= "table" or type(bar) ~= "table" or read(frame.IsForbidden, frame) == true
        or read(bar.IsForbidden, bar) == true or read(frame.IsVisible, frame) ~= true then return end
    return frame, bar, nil
  end
  -- X-Perl (and its forks, which keep the frame names) hides Blizzard's frames and draws XPerl_<Part>, with the bar
  -- at .statsFrame.healthBar and the portrait in .portraitFrame. It can be loaded with one frame type switched
  -- off, so its frame only counts while it is on screen or Blizzard's carries X-Perl's own "disabled" flag.
  local perl = _G["XPerl_" .. part]
  if type(perl) == "table" and read(perl.IsForbidden, perl) ~= true and (read(perl.IsVisible, perl) == true
      or (type(blizzard) == "table" and read(function() return blizzard.XPerlDisabled end) == true)) then
    local stats = read(function() return perl.statsFrame end)
    local bar = type(stats) == "table" and read(function() return stats.healthBar end)
    if type(bar) ~= "table" then bar = _G["XPerl_" .. part .. "statsFramehealthBar"] end
    if type(bar) == "table" and read(bar.IsForbidden, bar) ~= true then
      local portrait = read(function() return perl.portraitFrame end)
      if type(portrait) ~= "table" then portrait = _G["XPerl_" .. part .. "portraitFrame"] end
      if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then portrait = nil end
      return perl, bar, portrait
    end
  end
  -- Frame addons registered in Core/Integrations (ElvUI, ...): host, bar, portrait of the unit's own frame.
  for _, source in ipairs(Plate.unitFrameSources) do
    local host, bar, portrait = source(unit, part)
    if host or bar then return host, bar, portrait end
  end
  local modules = type(EllesmereUI) == "table" and EllesmereUI._ModuleNS
  local eui = type(modules) == "table" and modules.EllesmereUIUnitFrames
  local source = type(eui) == "table" and read(eui.GetUnitFrameSource, unit)
  if source == "hidden" then return end
  local custom = _G["EllesmereUIUnitFrames_" .. part]
  if source == "eui" or (source ~= "blizzard" and type(custom) == "table"
      and read(custom.IsVisible, custom) == true) then
    if type(custom) ~= "table" or read(custom.IsForbidden, custom) == true then return end
    local bar, portrait = custom.Health, custom.Portrait
    if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then return end
    if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then portrait = nil end
    return custom, bar, portrait
  end
  local frame
  if unit == "player" then frame = PlayerFrame elseif unit == "focus" then frame = FocusFrame else frame = TargetFrame end
  local content = type(frame) == "table" and (unit == "player" and frame.PlayerFrameContent or frame.TargetFrameContent)
  local main = type(content) == "table" and (unit == "player" and content.PlayerFrameContentMain or content.TargetFrameContentMain)
  local container = type(main) == "table" and main.HealthBarsContainer
  local bar = type(container) == "table" and container.HealthBar
  if type(bar) ~= "table" then bar = type(main) == "table" and main.HealthBar end
  if type(bar) ~= "table" then bar = type(frame) == "table" and frame.HealthBar end
  if type(bar) ~= "table" then bar = type(frame) == "table" and frame.healthbar end
  if type(bar) ~= "table" then bar = _G[part .. "FrameHealthBar"] end
  -- BetterBlizzFrames hides the original bar when its larger target/focus mirror is active.
  if unit ~= "player" and type(BBF) == "table" and type(frame) == "table" then
    local mirror = read(BBF.HealthBar, frame)
    if type(mirror) == "table" then bar = mirror end
  end
  -- The unit is there but Blizzard's bar is not on screen: a unit frame addon this file does not know has hidden
  -- it. Marks laid over a hidden bar float wherever that bar was left, so there is nothing to mark (a frame
  -- named with /upt frame is used above). Without the unit the frame is merely hidden, and stays the answer.
  if type(bar) == "table" and read(bar.IsVisible, bar) == false
      and read(UnitExists, FRAME_PART[unit] and unit or "target") == true then return end
  local portraitHost = type(frame) == "table" and frame.TargetFrameContainer
  local portrait = type(portraitHost) == "table" and portraitHost.Portrait
  if type(portrait) ~= "table" then portrait = _G[part .. "FramePortrait"] end
  if type(portrait) ~= "table" then portrait = type(frame) == "table" and frame.portrait end
  return frame, bar, portrait
end

-- Whether a health bar's fill runs right to left, so marks measured from "no health" start at its right edge:
-- a StatusBar with reverse fill (mirrored unit frames), or X-Perl's inverse bars, which fill with the health
-- that is missing and leave the health that remains at the right end.
function Plate.FillsReversed(bar)
  if type(bar) ~= "table" then return false end
  local reverse = read(bar.GetReverseFill, bar) == true
  local name = read(bar.GetName, bar)
  if type(name) == "string" and name:find("^XPerl_") and type(XPerlDB) == "table" then
    local inverse = read(function() return XPerlDB.bar.inverse end)
    if inverse then reverse = not reverse end
  end
  return reverse
end

-- Blizzard's Camelot unit frames make the HealthBar frame taller than the bar the player sees: it starts 3 above its
-- container (HealthBarsContainer, 126 x 15) and ends 2 below it, and the container's HealthBarMask cuts the fill to the
-- container's shape. Marks laid over the whole frame stick out above and below the visible bar (an outline, a glow), so
-- they take the container's top and bottom. Returns how far the visible bar lies inside the frame at the top and at the
-- bottom, in the frame's own units: 0, 0 for any other frame (no mask-holding container of the same width, a container
-- that is not smaller) and whenever the numbers cannot be read.
local insetCache = setmetatable({}, { __mode = "k" })
local INSET_TTL = 1 -- the frame's layout does not change from one draw to the next: asked once a second per bar

function Plate.BarInset(bar)
  if type(bar) ~= "table" then return 0, 0 end
  local now, cached = GetTime(), insetCache[bar]
  if cached and now - cached.at < INSET_TTL then return cached.top, cached.bottom end
  local top, bottom = Plate.ReadBarInset(bar)
  if cached then
    cached.top, cached.bottom, cached.at = top, bottom, now
  else
    insetCache[bar] = { top = top, bottom = bottom, at = now }
  end
  return top, bottom
end

function Plate.ReadBarInset(bar)
  local ok, top, bottom = pcall(function()
    local container = bar:GetParent()
    if type(container) ~= "table" or container.HealthBarMask == nil then return 0, 0 end
    local values = { bar:GetTop(), bar:GetBottom(), bar:GetLeft(), bar:GetRight(),
      container:GetTop(), container:GetBottom(), container:GetLeft(), container:GetRight() }
    for i = 1, 8 do
      local v = values[i]
      if type(v) ~= "number" or (type(issecretvalue) == "function" and issecretvalue(v)) then return 0, 0 end
    end
    local barTop, barBottom, barLeft, barRight, boxTop, boxBottom, boxLeft, boxRight = unpack(values)
    local insetTop, insetBottom = barTop - boxTop, boxBottom - barBottom
    if math.abs(barLeft - boxLeft) > 1 or math.abs(barRight - boxRight) > 1 then return 0, 0 end
    if insetTop < 0 or insetBottom < 0 or insetTop + insetBottom <= 0 or insetTop + insetBottom >= (barTop - barBottom) then
      return 0, 0
    end
    return insetTop, insetBottom
  end)
  if ok and type(top) == "number" and type(bottom) == "number" then return top, bottom end
  return 0, 0
end

-- The frame, health bar and portrait of a unit's frame. The kill icon spot the player named (Core/Frames.lua) replaces
-- the portrait of the target frame, whichever frame the bar comes from.
function Plate.UnitFrame(unit)
  local host, bar, portrait = unitFrameBase(unit)
  local Frames = BIT.Frames
  if Frames and (host or bar) and unit ~= "player" and unit ~= "focus" then
    local icon = Frames.Resolve(Frames.Get("icon"))
    if icon then portrait = icon end
  end
  return host, bar, portrait
end

local function visibleHealthBar(bar)
  local ok, visible = pcall(function()
    if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true
      or read(bar.IsVisible, bar) == false then return false end
    local alpha = read(bar.GetEffectiveAlpha, bar)
    return type(alpha) ~= "number" or alpha > 0
  end)
  return ok and visible == true
end

-- For the integrations: Plate.Read is the pcall reader of this file, Plate.VisibleHealthBar its visibility test.
function Plate.Read(fn, ...) return read(fn, ...) end
function Plate.VisibleHealthBar(bar) return visibleHealthBar(bar) end

local function isUnder(frame, plate)
  for _ = 1, 12 do
    frame = read(function() return frame:GetParent() end)
    if type(frame) ~= "table" then return false end
    if frame == plate then return true end
  end
  return false
end

-- Adapted from Does It Die (Joe Greive, MIT); see Modules/DoTInfo/LICENSE-DoesItDie.txt.
local SEARCH_DEPTH, MAX_TABLE_ENTRIES, SEARCH_INTERVAL = 4, 200, 1
local searchCache = setmetatable({}, { __mode = "k" })

local function tableFields(container, plain)
  local ok, fields = pcall(function()
    local found, count = {}, 0
    for key, value in pairs(container) do
      count = count + 1
      if plain and count > MAX_TABLE_ENTRIES then return end
      if type(key) == "string" and type(value) == "table" then
        found[#found + 1] = { key, value }
      end
    end
    table.sort(found, function(a, b) return a[1] < b[1] end)
    return found
  end)
  if ok then return fields end
end

local function searchHealthBar(plate)
  local unitFrame = read(function() return plate.UnitFrame end)
  local queue = { { node = plate, path = "", depth = 0, plain = false } }
  local seen, head = { [plate] = true }, 1
  while queue[head] do
    local item = queue[head]
    head = head + 1
    local fields = tableFields(item.node, item.plain)
    if fields then
      for _, field in ipairs(fields) do
        local key, value = field[1], field[2]
        local ok, found = pcall(function()
          return key:lower():find("health", 1, true) and read(value.GetObjectType, value) == "StatusBar"
            and visibleHealthBar(value) and isUnder(value, plate)
        end)
        if ok and found then return value, "auto " .. item.path .. key end
      end
      if item.depth < SEARCH_DEPTH then
        for _, field in ipairs(fields) do
          local key, value = field[1], field[2]
          if not seen[value] and value ~= unitFrame then
            seen[value] = true
            -- A broken framework object must not stop the other branches.
            local ok, frame = pcall(function() return value:GetObjectType() end)
            frame = ok and type(frame) == "string"
            local visit = not frame or read(function()
              return read(value.IsForbidden, value) == false
                and read(value.GetObjectType, value) ~= "StatusBar" and isUnder(value, plate)
            end)
            if visit then
              queue[#queue + 1] = { node = value, path = item.path .. key .. ".",
                depth = item.depth + 1, plain = not frame }
            end
          end
        end
      end
    end
  end
end

-- A plate with no health bar to find (a name-only plate of a friendly NPC, say) was searched again every second, one
-- walk over the plate's whole frame tree each, for every such plate on screen. A search that finds nothing now waits
-- twice as long before the next one (1, 2, 4, then 8 seconds); a plate handed to another unit starts over (below).
local FAIL_BACKOFF_STEPS = 3
local function searchWait(cached) return SEARCH_INTERVAL * 2 ^ math.min(cached.fails or 0, FAIL_BACKOFF_STEPS) end

local function autoHealthBar(plate)
  local cached, now = searchCache[plate], GetTime()
  if cached and cached.bar and visibleHealthBar(cached.bar) and isUnder(cached.bar, plate) then
    return cached.bar, cached.path
  end
  if cached and now - cached.at < searchWait(cached) then return nil, "health bar search pending" end
  local ok, bar, path = pcall(searchHealthBar, plate)
  if not ok then bar, path = nil, "health bar search unavailable" end
  searchCache[plate] = { bar = bar, path = path, at = now, fails = bar and 0 or ((cached and cached.fails or 0) + 1) }
  return bar, path or "no visible health bar found"
end

-- Threat Plates parents its plate frame to WorldFrame, so the search above never reaches it: the plate only
-- references it as plate.TPFrame (Active while Threat Plates draws the unit), with the bar at .visual.Healthbar
-- (.healthbar in older versions). Adapted from Does It Die v0.8.4.
local function threatPlatesBar(plate)
  local tp = plate.TPFrame
  if type(tp) ~= "table" or tp.Active ~= true or type(tp.visual) ~= "table" then return end
  local bar = tp.visual.Healthbar
  if not visibleHealthBar(bar) then bar = tp.visual.healthbar end
  if visibleHealthBar(bar) then return bar end
end

-- Prefer known integrations, then visible Blizzard bars, then a cached search of addon fields.
function Plate.WidgetHost(plate)
  if type(plate) ~= "table" then return nil end
  local unitFrame = read(function() return plate.unitFrame end)
  if type(unitFrame) == "table" and read(function() return unitFrame.PlateFrame end) == plate then
    return unitFrame
  end
  return plate
end

local function resolveHealthBar(plate)
  if type(plate) ~= "table" then return nil, "no nameplate" end
  if read(plate.IsForbidden, plate) == true then return nil, "forbidden nameplate" end
  local Frames = BIT.Frames
  if Frames then
    local path = Frames.Get("plate")
    if path ~= "" then
      local bar = Frames.ResolveFromPlate(plate, path)
      if bar and visibleHealthBar(bar) then return bar, "custom " .. path end
    end
  end
  for _, source in ipairs(Plate.plateBarSources) do
    local bar, path = source(plate)
    if bar then return bar, path end
  end
  if type(EllesmereNameplates_NS) == "table" then
    local children = { pcall(plate.GetChildren, plate) }
    if children[1] then
      for i = 2, #children do
        local ok, bar = pcall(function()
          local child = children[i]
          if child.nameplate == plate and type(child.health) == "table" and child:IsVisible()
            and visibleHealthBar(child.health) then return child.health end
        end)
        if ok and type(bar) == "table" then return bar, "EllesmereUINameplates.health" end
      end
    end
  end
  if type(Platynator) == "table" then
    local children = { pcall(plate.GetChildren, plate) }
    if children[1] then
      for i = 2, #children do
        local child = children[i]
        local ok, bar = pcall(function()
          if type(child.widgets) ~= "table" or not child:IsVisible() then return end
          for _, widget in ipairs(child.widgets) do
            if type(widget.details) == "table" and widget.details.kind == "health"
              and visibleHealthBar(widget.statusBar) then
              return widget.statusBar
            end
          end
        end)
        if ok and type(bar) == "table" then return bar, "Platynator.widgets.health.statusBar" end
      end
    end
  end
  local host = Plate.WidgetHost(plate)
  if host ~= plate then
    local bar = read(function() return host.healthBar end)
    if visibleHealthBar(bar) then return bar, "Plater.unitFrame.healthBar" end
  end
  local tpOk, tpBar = pcall(threatPlatesBar, plate)
  if tpOk and tpBar then return tpBar, "ThreatPlates.TPFrame.visual.Healthbar" end
  local ok, bar, path = pcall(function()
    local unitFrame = plate.UnitFrame
    if type(unitFrame) ~= "table" then return end
    local container = unitFrame.HealthBarsContainer
    if type(container) == "table" then
      if visibleHealthBar(container.healthBar) then return container.healthBar, "UnitFrame.HealthBarsContainer.healthBar" end
      if visibleHealthBar(container.HealthBar) then return container.HealthBar, "UnitFrame.HealthBarsContainer.HealthBar" end
    end
    if visibleHealthBar(unitFrame.healthBar) then return unitFrame.healthBar, "UnitFrame.healthBar" end
    if visibleHealthBar(unitFrame.HealthBar) then return unitFrame.HealthBar, "UnitFrame.HealthBar" end
  end)
  if ok and bar then return bar, path end
  return autoHealthBar(plate)
end

-- Every module with something on a plate asks for its health bar, several of them on every tick (ShieldsInfo for every
-- plate on screen, the DoT markers, the cast marker, the range icon): the answer, a bar or none, is kept for a quarter
-- of a second per plate, so the lookup above runs a few times a second for a plate however many ask. A plate that is
-- handed to another unit forgets it at once.
local lookupCache = setmetatable({}, { __mode = "k" })
local LOOKUP_TTL = 0.25

function Plate.HealthBar(plate)
  if type(plate) ~= "table" then return nil, "no nameplate" end
  local entry, now = lookupCache[plate], GetTime()
  if entry and now - entry.at < LOOKUP_TTL then return entry.bar, entry.path end
  local bar, path = resolveHealthBar(plate)
  if entry then
    entry.bar, entry.path, entry.at = bar, path, now
  else
    lookupCache[plate] = { bar = bar, path = path, at = now }
  end
  return bar, path
end

do
  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  watcher:SetScript("OnEvent", function(_, _, unit)
    if type(unit) ~= "string" or (type(issecretvalue) == "function" and issecretvalue(unit))
      or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and type(plate) == "table" then
      lookupCache[plate] = nil
      searchCache[plate] = nil
    end
  end)
end

-- Blizzard's own Mouseover Cast (Options > Combat, no macro): with it on and its key held (or none set), a cast
-- goes on the mob under the mouse whatever the target is. Names cannot tell that apart: in a pack every mob shares
-- the target's name. Returns "mouseover" when such a cast would land there: the option is plainly on, the unit is
-- attackable and alive, and the cast names no other mob (sentName unreadable or empty counts as no name).
-- Adapted from Does It Die v0.9.4 (Joe Greive, MIT).
function Plate.MouseoverCastUnit(sentName)
  local getBool = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
  if read(getBool, "enableMouseoverCast") ~= true then return nil end
  local key = read(GetModifiedClick, "MOUSEOVERCAST")
  if key ~= "NONE" and read(IsModifiedClick, "MOUSEOVERCAST") ~= true then return nil end
  if read(UnitExists, "mouseover") ~= true or read(UnitCanAttack, "player", "mouseover") ~= true
      or read(UnitIsDeadOrGhost, "mouseover") == true then return nil end
  local secret = type(issecretvalue) == "function" and issecretvalue(sentName)
  if not secret and type(sentName) == "string" and sentName ~= "" and read(UnitName, "mouseover") ~= sentName then
    return nil
  end
  return "mouseover"
end

-- Bottom and top of a widget seated with the live formula, positive y up.
function Plate.Span(offset, height)
  local top = -(tonumber(offset) or 0)
  local h = tonumber(height) or 0
  if h < 0 then h = 0 end
  return top - h, top
end

-- True when the two bodies share any vertical space. Touching edges do not count.
function Plate.Clash(offsetA, heightA, offsetB, heightB)
  local a0, a1 = Plate.Span(offsetA, heightA)
  local b0, b1 = Plate.Span(offsetB, heightB)
  return a0 < b1 and b0 < a1
end

local function moduleSettings(name)
  if type(BIT.DB) ~= "function" then return nil end
  local saved = BIT.DB()
  local modules = type(saved) == "table" and saved.modules or nil
  local s = type(modules) == "table" and modules[name] or nil
  if type(s) ~= "table" then return nil end
  return s
end

-- Hunter rail offset, combo-dot offset, shard offset. Missing saved values are the defaults.
function Plate.ReadOffsets()
  local hunter = -60
  local hs = moduleSettings("HunterRangeFinder")
  if hs and type(hs.plateOffset) == "number" then hunter = hs.plateOffset end
  local dots, shards = -60, -60
  local rd = Ready2QuestCombat_ResourceDingDB
  if type(rd) == "table" then
    if type(rd.dotOffset) == "number" then dots = rd.dotOffset end
    if type(rd.shardOffset) == "number" then shards = rd.shardOffset end
  end
  return hunter, dots, shards
end

-- The hunter rail is actually on the plate: the module is running, the player is a hunter,
-- and the rail is attached. A non-hunter keeps the Range check even if this module is on.
function Plate.HunterOwnsNameplate(plate)
  if plate then
    local hunter = BIT.modules and BIT.modules.HunterRangeFinder
    return hunter and type(hunter.OwnsNameplate) == "function" and hunter.OwnsNameplate(plate) or false
  end
  if type(BIT.IsRunning) ~= "function" or not BIT.IsRunning("HunterRangeFinder") then return false end
  local class
  if type(UnitClass) == "function" then
    class = select(2, UnitClass("player"))
  end
  if type(issecretvalue) == "function" and issecretvalue(class) then return false end
  if class ~= "HUNTER" then return false end
  local s = moduleSettings("HunterRangeFinder")
  if s and s.attachToPlate == false then return false end
  return true
end

-- DoTInfo has a marker's worth of damage on this unit. Shields use it to yield the fill.
function Plate.DotOnUnit(unit)
  if type(unit) ~= "string" then return false end
  if type(BIT.IsRunning) ~= "function" or not BIT.IsRunning("DoTInfo") then return false end
  local dot = BIT.modules and BIT.modules.DoTInfo
  if type(dot) ~= "table" or type(dot.HasMarker) ~= "function" then return false end
  local ok, on = pcall(dot.HasMarker, unit)
  return ok and on == true
end

-- A refresh is due when time left is still positive and inside the largest of one tick,
-- three seconds, and a quarter of the duration.
function Plate.RefreshDue(remaining, duration, interval)
  remaining = tonumber(remaining)
  if not remaining or remaining <= 0 then return false end
  duration = tonumber(duration) or 0
  interval = tonumber(interval) or 0
  if interval < 0 then interval = 0 end
  local portion = duration > 0 and duration * 0.25 or 0
  local window = math.max(interval, 3, portion)
  return remaining <= window
end

-- Available indicator rows on this character, independent of whether a target
-- currently exists. These dimensions drive the settings overlap warnings.
function Plate.Rows()
  local function on(name)
    return BIT.IsRunning(name) or (BIT.woke and BIT.woke[name] == true)
  end
  local hunter, dots, shards = Plate.ReadOffsets()
  local rd = Ready2QuestCombat_ResourceDingDB or {}
  local size = math.min(24, math.max(8, tonumber(rd.dotSize) or 14))
  local resource = BIT.modules and BIT.modules.ResourceDing
  local kind = resource and resource.GetResource and resource.GetResource()
  local hasPoints = false
  if kind and type(resource.GetResourceState) == "function" then
    local ok, _, _, maximum = pcall(resource.GetResourceState)
    hasPoints = ok and type(maximum) == "number" and maximum > 0
  end
  local class = type(UnitClass) == "function" and select(2, UnitClass("player"))
  local catForm = false
  if class == "DRUID" and type(GetShapeshiftFormID) == "function" then
    local ok, form = pcall(GetShapeshiftFormID)
    if ok then
      local readable = true
      if type(issecretvalue) == "function" then
        local checked, secret = pcall(issecretvalue, form)
        readable = checked and not secret
      end
      catForm = readable and form == 1
    end
  end
  local classicShards = resource and type(resource.IsClassic) == "function" and resource.IsClassic()
  local hasDiamonds = on("ResourceDing") and rd.enabled ~= false and rd.shardDiamonds ~= false
    and class == "WARLOCK" and (classicShards or hasPoints)
  local hs = moduleSettings("HunterRangeFinder") or {}
  return {
    hunter = { on = on("HunterRangeFinder") and class == "HUNTER" and hs.attachToPlate ~= false,
      offset = hunter, height = Plate.HUNTER_RAIL_HEIGHT },
    dots = { on = on("ResourceDing") and rd.enabled ~= false and rd.dots ~= false and hasPoints
      and not hasDiamonds and (class ~= "DRUID" or catForm),
      offset = dots, height = size },
    shards = { on = hasDiamonds,
      offset = shards, height = size },
  }
end

function Plate.ClashText(rows)
  rows = rows or Plate.Rows()
  local parts = {}
  local function check(a, b, text)
    if a.on and b.on and Plate.Clash(a.offset, a.height, b.offset, b.height) then
      parts[#parts + 1] = text
    end
  end
  check(rows.hunter, rows.dots, BIT.L("Hunter rail overlaps combo dots."))
  check(rows.hunter, rows.shards, BIT.L("Hunter rail overlaps shard diamonds."))
  check(rows.dots, rows.shards, BIT.L("Combo dots overlap shard diamonds."))
  if #parts == 0 then return BIT.L("Nameplate lanes are clear.") end
  return table.concat(parts, " ")
end
