-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the shared appearance layer (BIT.Style) and the shared appearance editor
-- (BIT.UI.Appearance).
--
-- Loaded after Core/Init.lua and before Core/Settings.lua. It defines:
--   BIT.Style.Resolve(moduleName, legacy)  a NEW sanitized style table
--   BIT.Style.Set(moduleName, key, value)  validated explicit writes to Ready2QuestCombatDB.appearance
--   BIT.Style.Reset(moduleName)            appearance-only reset, "*"/nil for the shared style
--   BIT.Style.Subscribe(moduleName, callback) -> unsubscribe function
--   BIT.Style.ApplyText(fontString, style, role)
--   BIT.Style.ApplyBar(statusBar, style, role)
--   BIT.Style.CreateMarkers(parent, count) / BIT.Style.RenderMarkers(container, style, active, total, role)
-- and, on BIT.UI: BIT.UI.Appearance(parent, moduleName, capabilities, refresh, legacy).
--
-- One product style, stored under Ready2QuestCombatDB.appearance:
--   appearance.global      shared style writes (Set with moduleName "*" or nil)
--   appearance.modules     per-module style writes (Set with a module name)
--   appearance.legacyBypass modules whose old fallback Reset() has disabled
-- Resolve precedence, weakest first: product defaults < legacy fallback < global writes <
-- per-module writes. The legacy fallback holds ONLY explicitly customized old visual values
-- (the caller supplies it as a table, or a function returning one); Reset(module) disables it
-- for that module in the same scope it clears. Resolve never writes to any saved variable and
-- never touches gameplay data; its result is always a fresh table whose nested tables alias
-- nothing.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Style = {}
BIT.Style = Style

local ROLES = {
  "accent", "text", "muted", "damage", "heal", "absorb", "good", "bad", "unknown",
  "resource", "distanceNear", "distanceMid", "distanceFar",
}
local ROLE_SET = {}
for i = 1, #ROLES do ROLE_SET[ROLES[i]] = true end

local OUTLINES = { NONE = true, OUTLINE = true, THICKOUTLINE = true }
local SHAPES = { segments = true, bar = true, dots = true, diamond = true }

-- The product preset "Minimal": calm, reduced motion on, one family of simple markers.
local DEFAULTS = {
  shape = "segments",
  opacity = 1,
  scale = 1,
  thickness = 4,
  gap = 3,
  length = 14,
  border = 1,
  font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
  fontSize = 12,
  outline = "OUTLINE",
  reducedMotion = true,
  colors = {
    accent       = { 0.40, 0.70, 1.00, 1 },
    text         = { 1.00, 1.00, 1.00, 1 },
    muted        = { 0.55, 0.55, 0.58, 1 },
    damage       = { 1.00, 0.40, 0.30, 1 },
    heal         = { 0.35, 1.00, 0.55, 1 },
    absorb       = { 0.45, 0.75, 1.00, 1 },
    good         = { 0.30, 1.00, 0.30, 1 },
    bad          = { 1.00, 0.25, 0.25, 1 },
    unknown      = { 0.55, 0.55, 0.60, 1 },
    resource     = { 1.00, 0.80, 0.20, 1 },
    distanceNear = { 0.30, 1.00, 0.30, 1 },
    distanceMid  = { 1.00, 0.80, 0.20, 1 },
    distanceFar  = { 1.00, 0.30, 0.30, 1 },
  },
}
Style.Defaults = DEFAULTS

-- Isolated per-module product defaults (runtime-only, never saved). Hunter and
-- future modules register their own Minimal starting point here; Resolve layers
-- it as product < moduleDefaults < legacy < global < per-module. The registry
-- holds sanitized clones only: no caller alias, no SavedVariables writes, no
-- unit reads, no frame creation, no notifications. The accessor functions live
-- below field()/color() (no forward references).
local ModuleDefaults = {}

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- One scalar field's sanitizer: a number is clamped into the field's bounds, anything else
-- (nil, string, table) falls back to the product default.
local BOUNDS = {
  opacity    = { 0,   1,   "opacity" },
  scale      = { 0.1, 10,  "scale" },
  thickness  = { 1,   64,  "thickness" },
  gap        = { 0,   64,  "gap" },
  length     = { 1,   128, "length" },
  border     = { 0,   16,  "border" },
  fontSize   = { 6,   48,  "fontSize" },
}

local function scalar(key, v)
  local b = BOUNDS[key]
  if not finite(v) then return DEFAULTS[key] end
  return clamp(v, b[1], b[2])
end

local function field(key, v)
  if key == "shape" then
    return type(v) == "string" and SHAPES[v] and v or DEFAULTS.shape
  elseif key == "outline" then
    return type(v) == "string" and OUTLINES[v] and v or DEFAULTS.outline
  elseif key == "font" then
    return type(v) == "string" and v ~= "" and v or DEFAULTS.font
  elseif key == "reducedMotion" then
    -- explicit branches: `and v or fallback` would turn a stored false back into true
    if type(v) == "boolean" then return v end
    return DEFAULTS.reducedMotion
  end
  return scalar(key, v)
end

local function copyColor(c)
  return { c[1], c[2], c[3], c[4] }
end

-- A role colour: a table of four numbers in 0..1, or the role's default (fresh copies always;
-- the result must never alias stored data or defaults).
local function color(role, v)
  local fallback = DEFAULTS.colors[role]
  if type(v) ~= "table" then return copyColor(fallback) end
  local a = v[4] == nil and 1 or v[4]
  if not finite(v[1]) or not finite(v[2]) or not finite(v[3]) or not finite(a) then
    return copyColor(fallback)
  end
  for i = 1, 3 do
    if v[i] < 0 or v[i] > 1 then return copyColor(fallback) end
  end
  if a < 0 or a > 1 then return copyColor(fallback) end
  return { v[1], v[2], v[3], a }
end

-- Sanitize one RegisterDefaults partial into a clean overlay (flat keys plus a
-- colors subtable, only known roles/keys, corrupt values fall back to the
-- product default, unknown keys/roles ignored). Always returns a fresh table.
local function sanitizeModulePartial(partial)
  local out = {}
  if type(partial) ~= "table" then return out end
  for _, key in ipairs({ "shape", "opacity", "scale", "thickness", "gap", "length",
    "border", "font", "fontSize", "outline", "reducedMotion" }) do
    local v = partial[key]
    if v ~= nil then
      out[key] = field(key, v)
    end
  end
  local pc = partial.colors
  if type(pc) == "table" then
    local clean
    for i = 1, #ROLES do
      local role = ROLES[i]
      local cv = pc[role]
      if cv ~= nil then
        clean = clean or {}
        clean[role] = color(role, cv)
      end
    end
    if clean then out.colors = clean end
  end
  return out
end

-- Register (or replace) the runtime defaults overlay for one module. Pure:
-- no SavedVariables writes, no notifications, no frames, no unit reads. The
-- partial is sanitized and cloned; later caller mutations never reach the
-- registry. Returns true on success, nil on an invalid name/partial.
function Style.RegisterDefaults(moduleName, partial)
  if type(moduleName) ~= "string" or moduleName == "" or moduleName == "*" then
    return nil
  end
  if type(partial) ~= "table" then return nil end
  ModuleDefaults[moduleName] = sanitizeModulePartial(partial)
  return true
end

-- The effective defaults for one module: product defaults overlaid with that
-- module's registered overlay (if any). Always a fresh table; mutating the
-- result never touches the registry, the caller partial or the product table.
function Style.GetDefaults(moduleName)
  local out = {}
  for key, v in pairs(DEFAULTS) do
    if key ~= "colors" then
      out[key] = v
    end
  end
  local colors = {}
  for role, c in pairs(DEFAULTS.colors) do
    colors[role] = { c[1], c[2], c[3], c[4] }
  end
  out.colors = colors
  local overlay
  if type(moduleName) == "string" then overlay = ModuleDefaults[moduleName] end
  if type(overlay) == "table" then
    for key, v in pairs(overlay) do
      if key ~= "colors" then
        out[key] = v
      end
    end
    if type(overlay.colors) == "table" then
      for role, c in pairs(overlay.colors) do
        if ROLE_SET[role] then
          out.colors[role] = { c[1], c[2], c[3], c[4] }
        end
      end
    end
  end
  return out
end

local function appearanceDB()
  local d = type(Ready2QuestCombatDB) == "table" and Ready2QuestCombatDB or nil
  if not d then return nil end
  local a = d.appearance
  return type(a) == "table" and a or nil
end

-- The three override layers a module's style resolves through, each a flat table of fields
-- with a colors mapping, or nil.
local function layers(moduleName, legacy)
  local a = appearanceDB()
  local globals = a and type(a.global) == "table" and a.global or nil
  local per = a and type(a.modules) == "table" and type(a.modules[moduleName]) == "table"
    and a.modules[moduleName] or nil
  local legacyTab
  local bypassed = a and type(a.legacyBypass) == "table" and a.legacyBypass[moduleName]
  if legacy and not bypassed then
    local t = type(legacy) == "function" and legacy() or legacy
    legacyTab = type(t) == "table" and t or nil
  end
  return per, globals, legacyTab
end

-- A fresh sanitized style table for one module. Pure: no saved-variable writes, no gameplay
-- API, no sharing of nested tables with defaults, the stored database or another Resolve.
function Style.Resolve(moduleName, legacy)
  local per, globals, legacyTab = layers(moduleName, legacy)
  -- runtime module overlay sits between product defaults and the legacy
  -- fallback: product < moduleDefaults < legacy < global < per-module
  local modOverlay = type(moduleName) == "string" and ModuleDefaults[moduleName] or nil
  if type(modOverlay) ~= "table" then modOverlay = nil end
  local out = {}
  for key in pairs(DEFAULTS) do
    if key ~= "colors" then
      local v
      if per and per[key] ~= nil then v = per[key]
      elseif globals and globals[key] ~= nil then v = globals[key]
      elseif legacyTab and legacyTab[key] ~= nil then v = legacyTab[key]
      elseif modOverlay and modOverlay[key] ~= nil then v = modOverlay[key]
      else v = DEFAULTS[key] end
      out[key] = field(key, v)
    end
  end
  local colors = {}
  for i = 1, #ROLES do
    local role = ROLES[i]
    local v
    -- every layer's colors mapping may be missing or corrupted (a number/string): only
    -- real tables are indexed, so malformed stored appearance can never crash Resolve
    local perColors = type(per) == "table" and per.colors
    local globalColors = type(globals) == "table" and globals.colors
    local legacyColors = type(legacyTab) == "table" and legacyTab.colors
    local modColors = modOverlay and modOverlay.colors or nil
    if type(perColors) == "table" and perColors[role] ~= nil then v = perColors[role]
    elseif type(globalColors) == "table" and globalColors[role] ~= nil then v = globalColors[role]
    elseif type(legacyColors) == "table" and legacyColors[role] ~= nil then v = legacyColors[role]
    elseif type(modColors) == "table" and modColors[role] ~= nil then v = modColors[role]
    else v = DEFAULTS.colors[role] end
    colors[role] = color(role, v)
  end
  out.colors = colors
    return out
  end

  ---------------------------------------------------------------------------------------------
  -- Validated writes, reset, subscription
  ---------------------------------------------------------------------------------------------

  local function ensureAppearance()
    if type(Ready2QuestCombatDB) ~= "table" then Ready2QuestCombatDB = {} end
    local a = Ready2QuestCombatDB.appearance
    if type(a) ~= "table" then a = {} Ready2QuestCombatDB.appearance = a end
    local globals = a.global
    if type(globals) ~= "table" then globals = {} a.global = globals end
    local modules = a.modules
    if type(modules) ~= "table" then modules = {} a.modules = modules end
    return a, globals, modules
  end

  -- Set's own strict check: the value must be a table of four numbers in 0..1 (nil alpha = 1).
  -- Returns (true, normalizedEntry) or false.
  local function validColorEntry(c)
    if type(c) ~= "table" then return false end
    local a = c[4] == nil and 1 or c[4]
    if type(c[1]) ~= "number" or type(c[2]) ~= "number" or type(c[3]) ~= "number" or type(a) ~= "number" then
      return false
    end
    if not (c[1] >= 0 and c[1] <= 1 and c[2] >= 0 and c[2] <= 1 and c[3] >= 0 and c[3] <= 1
      and a >= 0 and a <= 1) then
      return false
    end
    return true, { c[1], c[2], c[3], a }
  end

  -- Strict per-key validation for explicit writes: false, nil means "refuse, write nothing".
  local function validField(key, v)
    if key == "shape" then
      return type(v) == "string" and SHAPES[v] ~= nil, v
    elseif key == "outline" then
      return type(v) == "string" and OUTLINES[v] ~= nil, v
    elseif key == "font" then
      return type(v) == "string" and v ~= "", v
    elseif key == "reducedMotion" then
      return type(v) == "boolean", v
    end
    local b = BOUNDS[key]
    if not b then return false end
    if not finite(v) then return false end
    return true, clamp(v, b[1], b[2])
  end

  local subscribers = {} -- key ("*" or a module name) -> list of callbacks

  local function notify(scope)
    for key, list in pairs(subscribers) do
      if key == "*" or key == scope or scope == "*" then
        for i = 1, #list do
          if list[i] then list[i](scope) end
        end
      end
    end
  end

  -- A validated explicit appearance write. moduleName "*" (or nil) writes the shared style, a
  -- module name writes that module's overrides. Invalid values are refused: nothing is written
  -- and nil is returned. A colours write is a mapping of roles; one unknown role or corrupt
  -- colour refuses the whole write. Each accepted Set notifies the subscribers once.
  function Style.Set(moduleName, key, value)
    if type(key) ~= "string" then return nil end
    local isGlobal = moduleName == nil or moduleName == "*"
    local scope = isGlobal and "*" or tostring(moduleName)
    local sanitized
    if key == "colors" then
      if type(value) ~= "table" then return nil end
      local clean = {}
      for role, c in pairs(value) do
        if type(role) ~= "string" or not ROLE_SET[role] then return nil end
        local ok, entry = validColorEntry(c)
        if not ok then return nil end
        clean[role] = { entry[1], entry[2], entry[3], entry[4] }
      end
      if next(clean) == nil then return nil end
      sanitized = clean
    else
      local ok, v = validField(key, value)
      if not ok then return nil end
      sanitized = v
    end

    local _, globals, modules = ensureAppearance()
    local layer = isGlobal and globals or modules[scope]
    if type(layer) ~= "table" then layer = {} modules[scope] = layer end
    if key == "colors" then
      if type(layer.colors) ~= "table" then layer.colors = {} end
      for role, c in pairs(sanitized) do layer.colors[role] = c end
    else
      layer[key] = sanitized
    end
    notify(scope)
    return sanitized
  end

  -- Reset only the appearance at the requested scope. "*"/nil resets the shared style; a module
  -- name clears that module's overrides and disables the old fallback for it (Resolve then skips
  -- its legacy values). Gameplay settings, anchors, sounds and learned values are never touched:
  -- only Ready2QuestCombatDB.appearance changes.
  function Style.Reset(moduleName)
    local isGlobal = moduleName == nil or moduleName == "*"
    if isGlobal then
      -- a global reset needs no store: with no appearance there is nothing to clear
      local a = appearanceDB()
      if a then a.global = nil end
    else
      -- a module reset must work before the appearance store exists too: the legacy
      -- bypass has to be recorded or the customized old fallback would reappear
      local a, _, modules = ensureAppearance()
      modules[moduleName] = nil
      local bypass = a.legacyBypass
      if type(bypass) ~= "table" then bypass = {} a.legacyBypass = bypass end
      bypass[moduleName] = true
    end
    notify(isGlobal and "*" or tostring(moduleName))
  end

  -- Register a callback for style changes: moduleName "*"/nil hears every change, a module name
  -- hears that module's writes (and, through the shared style, global ones). Returns the
  -- unsubscribe function; calling it removes the callback.
  function Style.Subscribe(moduleName, callback)
    local key = moduleName == nil and "*" or tostring(moduleName)
    local list = subscribers[key]
    if not list then list = {} subscribers[key] = list end
    list[#list + 1] = callback
    return function()
      for i = #list, 1, -1 do
        if list[i] == callback then table.remove(list, i) end
      end
    end
  end

  ---------------------------------------------------------------------------------------------
  -- Applying the style to widgets
  ---------------------------------------------------------------------------------------------

  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local INACTIVE_ALPHA = 0.25 -- the dim level of inactive markers

  local function roleColor(style, role)
    return style.colors[role] or style.colors.text
  end

  -- Apply the style's font, size and outline plus the role colour to one font string. The final
  -- alpha combines the role's own with the flat style opacity. Nothing outside the font string
  -- changes: the game tooltip and its globals are never touched.
  function Style.ApplyText(fontString, style, role)
    if not fontString then return end
    local c = roleColor(style, role)
    -- NONE is the editor/storage sentinel for "no outline", not a native flag:
    -- the client rejects it (bad argument #3), so translate only here to native
    -- no-outline (""). Stored and resolved outlines keep NONE unchanged.
    local flags = style.outline
    if flags == "NONE" then flags = "" end
    fontString:SetFont(style.font, style.fontSize, flags)
    fontString:SetTextColor(c[1], c[2], c[3], c[4] * style.opacity)
  end

  -- Configure one status bar as the native WHITE8X8 fill in the role colour at the style opacity.
  -- Secret-safe by construction: only the texture and colour are touched. The bar's value is
  -- never read, divided, compared or formatted here; callers pass raw values only to the native
  -- SetValue / SetMinMaxValues / SetFormattedText.
  function Style.ApplyBar(statusBar, style, role)
    if not statusBar then return end
    local c = roleColor(style, role)
    statusBar:SetStatusBarTexture(WHITE)
    statusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] * style.opacity)
  end

  -- A container owning count solid markers, each a bordered frame with a WHITE8X8 fill.
  -- The border stroke is drawn by the client's Backdrop API, which only exists on frames
  -- constructed with the BackdropTemplate mixin (Backdrop-template-primary.xml). When the
  -- client exposes that mixin and accepts the template, holders are built with it so the
  -- factory's own frames carry an editable stroke; a legacy/no-template client gets plain
  -- holders and paint() keeps its guarded no-op. The caller lays the container out;
  -- RenderMarkers draws into it.
  function Style.CreateMarkers(parent, count)
    local container = CreateFrame("Frame", nil, parent)
    container.markers = {}
    count = tonumber(count) or 0
    -- The template probe runs once per session, not once per panel: it used to create and
    -- throw away a real frame on every call (each appearance panel and every cached scene).
    if Style._holderTemplate == nil then
      local found = false
      if type(BackdropTemplateMixin) == "table" then
        local ok = pcall(CreateFrame, "Frame", nil, nil, "BackdropTemplate")
        if ok then found = "BackdropTemplate" end
      end
      Style._holderTemplate = found
    end
    local holderTemplate = Style._holderTemplate or nil
    for i = 1, count do
      local holder = CreateFrame("Frame", nil, container, holderTemplate)
      local fill = holder:CreateTexture(nil, "ARTWORK")
      fill:SetTexture(WHITE)
      fill:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
      fill:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
      holder.fill = fill
      container.markers[i] = holder
    end
    return container
  end

  -- The border stroke needs the client's Backdrop API: only frames with the
  -- BackdropTemplate mixin (or a client that always provides it) carry SetBackdrop.
  -- Absent API must not crash the markers, and a zero border must clear the stroke
  -- that an earlier render drew (native SetBackdrop(nil) clears, per Backdrop.lua).
  local function paint(holder, style, c, alpha)
    local border = style.border
    local hasBackdrop = type(holder.SetBackdrop) == "function"
    if border > 0 then
      if hasBackdrop then
        holder:SetBackdrop({ edgeFile = WHITE, edgeSize = border })
        if type(holder.SetBackdropBorderColor) == "function" then
          holder:SetBackdropBorderColor(c[1], c[2], c[3], alpha)
        end
      end
    elseif hasBackdrop then
      holder:SetBackdrop(nil)
    end
    holder.fill:SetColorTexture(c[1], c[2], c[3], alpha)
  end

  local function toSquare(holder)
    if holder.orb then holder.orb:Hide() end
    holder.fill:Show()
    holder.fill:SetTexture(WHITE)
    holder.fill:SetVertexColor(1, 1, 1, 1)
    holder.fill:ClearAllPoints()
    holder.fill:SetAllPoints(holder)
  end

  -- Render markers into a container from a resolved style. activeCount and totalCount are plain
  -- readable values from the module's own guards; clamped to 0..totalCount here. The marker
  -- family: segments (length x thickness on a gap), dots (round CIRCLE discs with an outset
  -- circular border, gap between painted extents), diamond (rotated squares, falling back to
  -- squares when the client has no SetRotation) and bar (one strip filled by the active
  -- share). The scale multiplies the geometry. No unit, target or game API is read here.
  function Style.RenderMarkers(container, style, activeCount, totalCount, role)
    local c = roleColor(style, role)
    local markers = container.markers
    totalCount = tonumber(totalCount) or 0
    totalCount = math.max(0, math.floor(totalCount))
    activeCount = tonumber(activeCount) or 0
    activeCount = math.max(0, math.min(totalCount, math.floor(activeCount)))
    local activeAlpha = c[4] * style.opacity
    local dimAlpha = activeAlpha * INACTIVE_ALPHA
    local thick = math.max(1, style.thickness * style.scale)
    local gap = math.max(0, style.gap * style.scale)
    local len = math.max(1, style.length * style.scale)

    if style.shape == "dots" then
      local borderPx = math.max(0, style.border * style.scale)
      local outer = thick + 2 * borderPx
      local step = outer + gap
      container:SetSize(totalCount > 0 and totalCount * step - gap or 0, outer)
      for i, holder in ipairs(markers) do
        holder:SetShown(i <= totalCount)
        if i <= totalCount then
          holder:SetSize(outer, outer)
          holder:ClearAllPoints()
          holder:SetPoint("TOPLEFT", container, "TOPLEFT", (i - 1) * step, 0)
          if holder.SetBackdrop then holder:SetBackdrop(nil) end
          holder.fill:Hide()
          local orb = holder.orb
          if not orb then orb = BIT.Orbs.Create(holder); holder.orb = orb end
          orb:ClearAllPoints()
          orb:SetPoint("TOPLEFT", holder, "TOPLEFT", borderPx, -borderPx)
          orb:SetSize(thick, thick)
          BIT.Orbs.Layout(orb, borderPx)
          orb.border:SetShown(borderPx > 0)
          orb:SetMinMaxValues(0, 1)
          orb:SetValue(i <= activeCount and 1 or 0)
          orb.overlay:Show()
          orb.overlay:SetMinMaxValues(0, 1)
          orb.overlay:SetValue(0)
          local alpha = i <= activeCount and activeAlpha or dimAlpha
          BIT.Orbs.Paint(orb, { c[1], c[2], c[3], alpha }, style.opacity)
          orb.glow:SetShown(i == activeCount and activeCount > 0 and not style.reducedMotion)
          orb:Show()
        end
      end
      return
    end

    if style.shape == "bar" then
      local fill, rest = markers[1], markers[2]
      local width = len
      container:SetSize(width, thick)
      local fillW = totalCount > 0 and math.max(0, len * activeCount / totalCount) or 0
      if fill then
        fill:SetShown(fillW > 0.5)
        fill:SetSize(fillW, thick)
        fill:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        toSquare(fill)
        paint(fill, style, c, activeAlpha)
        if rest then
          rest:SetShown(fillW < width - 0.5)
          rest:SetSize(math.max(0, width - fillW), thick)
          rest:SetPoint("TOPLEFT", container, "TOPLEFT", fillW, 0)
          -- The remainder is always the inactive share, even when a sub-half-pixel
          -- active fill is hidden. Keep its quarter-alpha contract at every width.
          toSquare(rest)
          paint(rest, style, c, dimAlpha)
        end
      end
      for i = 3, #markers do markers[i]:SetShown(false) toSquare(markers[i]) end
      -- leaving the diamond must not keep the stale 45-degree turn on the bar's own
      -- fill/remainder either (direct diamond -> bar, no intermediate shape); guarded
      -- so rotation-less clients keep their plain fallback
      pcall(function()
        for i = 1, #markers do
          markers[i].fill:SetRotation(0)
        end
      end)
      return
    end

    local step = style.shape == "segments" and len + gap or thick + gap
    local mw, mh = style.shape == "segments" and len or thick, thick
    local width = totalCount > 0 and totalCount * step - gap or 0
    container:SetSize(width, mh)
    for i = 1, #markers do
      local m = markers[i]
      if i <= totalCount then
        m:SetShown(true)
        m:SetSize(mw, mh)
        m:SetPoint("TOPLEFT", container, "TOPLEFT", (i - 1) * step, 0)
        toSquare(m)
        paint(m, style, c, i <= activeCount and activeAlpha or dimAlpha)
      else
        m:SetShown(false)
        toSquare(m)
      end
    end
    if style.shape == "diamond" then
      local ok = pcall(function()
        for i = 1, math.min(totalCount, #markers) do
          markers[i].fill:SetRotation(math.pi / 4)
        end
      end)
      if not ok then
        -- a client without texture rotation: the squares stay squares
      end
    else
      -- leaving the diamond must not keep the stale 45-degree turn; guarded so
      -- clients without texture rotation keep their plain-squares fallback
      pcall(function()
        for i = 1, #markers do
          markers[i].fill:SetRotation(0)
        end
      end)
    end
  end

-- Remove one role-colour write from a scope, so an edit can return to "no override" (the
-- colour picker's Cancel). Nothing else changes; notifies once when something was removed.
function Style.RemoveColor(moduleName, role)
  if type(role) ~= "string" or not ROLE_SET[role] then return nil end
  local isGlobal = moduleName == nil or moduleName == "*"
  local a = appearanceDB()
  if not a then return nil end
  local layer = isGlobal and a.global or (type(a.modules) == "table" and a.modules[moduleName] or nil)
  if type(layer) ~= "table" or type(layer.colors) ~= "table" or layer.colors[role] == nil then return nil end
  local removed = layer.colors[role]
  layer.colors[role] = nil
  notify(isGlobal and "*" or tostring(moduleName))
  return removed
end

---------------------------------------------------------------------------------------------
-- The shared appearance editor (BIT.UI.Appearance)
---------------------------------------------------------------------------------------------
-- One panel of Appearance controls for a module: the palette (native Blizzard ColorPickerFrame
-- with a validated RGB edit-box fallback), opacity, the shape/font/geometry/border/scale
-- controls the capabilities allow, reduced motion, the product Minimal preset, an
-- appearance-only reset labelled by scope, and a sample preview made of the shared primitives
-- (explicit fictitious data; no gameplay, events, timers or sounds).
--
-- capabilities (all optional):
--   roles    list of palette roles to edit (default: all thirteen)
--   shapes   list of shape names for the shape control (no control without it)
--   font     show font size / outline / font path controls
--   geometry show thickness / gap / length controls
--   border   show the border control
--   scale    show the scale control
--   opacity  default true; false hides the opacity control
--   width    panel width in px (default 560); the height is computed and declared
-- refresh   optional function re-applying the module's real display and its own preview,
--           called once after every style change that touches this module (never while it is
--           being built)
-- legacy    optional table/function, passed to Resolve for this module's fallback
--
-- The returned frame has Refresh (re-build the controls and sample from the current style),
-- SetPoint and a declared size; panel.controls exposes scope/swatches/sliders/checks/shape/
-- outline/reset/preset for module workers; panel.Release unsubscribes from style changes.

BIT.UI = BIT.UI or {}

local SAMPLE_TEXT = "Sample text 123"
local SAMPLE_MARKERS_TOTAL, SAMPLE_MARKERS_ACTIVE = 5, 3
local SAMPLE_BAR_MAX, SAMPLE_BAR_VALUE = 100, 62

-- Opens Blizzard's native ColorPickerFrame (classic-era SetupColorPickerAndShow, as in the
-- Blizzard reference source). commit(r, g, b, a) runs while the user drags; cancel() runs on
-- Cancel with the values the dialog opened with. Returns true when the native picker exists.
local function openNativeColorPicker(commit, r, g, b, a, hasOpacity, cancel)
  local picker = ColorPickerFrame
  if not picker or type(picker.SetupColorPickerAndShow) ~= "function" then return false end
  -- Setup dispatches both swatch and opacity callbacks on some clients. Suppress
  -- initialization by phase, not by guessing how many callbacks it produces.
  local initializing = true
  local changed = function()
    if initializing then return end
    local cr, cg, cb = picker:GetColorRGB()
    commit(cr, cg, cb, hasOpacity and picker:GetColorAlpha() or a)
  end
  picker:SetupColorPickerAndShow({
    r = r, g = g, b = b, opacity = a, hasOpacity = hasOpacity,
    swatchFunc = changed,
    opacityFunc = changed,
    cancelFunc = function(previous)
      if previous then
        -- Blizzard hands back the setup table, which carries the alpha as "opacity"; reading
        -- previous.a alone dropped every translucent role color back to opaque on Cancel.
        local a = previous.opacity
        if type(a) ~= "number" then a = previous.a end
        if type(a) ~= "number" then a = 1 end
        cancel(previous.r, previous.g, previous.b, a)
      end
    end,
  })
  initializing = false
  return true
end

-- The role colour currently stored as an explicit write at a scope, or nil.
local function priorColorWrite(scope, role)
  local a = appearanceDB()
  if not a then return nil end
  local layer = scope == "*" and a.global or (type(a.modules) == "table" and a.modules[scope] or nil)
  if type(layer) == "table" and type(layer.colors) == "table" then return layer.colors[role] end
  return nil
end

function BIT.UI.Appearance(parent, moduleName, capabilities, refresh, legacy)
  capabilities = capabilities or {}
  local roles = capabilities.roles or ROLES
  local width = capabilities.width or 560
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetWidth(width)

  local controls = { sliders = {}, checks = {}, swatches = {}, rgb = {} }
  panel.controls = controls
  panel.sliders, panel.checks = controls.sliders, controls.checks

  local x = 12
  local y = -8
  local scopeIsGlobal = false
  local refreshPanel

  local function scopeKey()
    return scopeIsGlobal and "*" or moduleName
  end
  local function currentStyle()
    if scopeIsGlobal then return Style.Resolve(nil) end
    return Style.Resolve(moduleName, legacy)
  end
  local function commit(key, value)
    Style.Set(scopeKey(), key, value)
  end
  local function commitColor(role, r, g, b, a)
    commit("colors", { [role] = { r, g, b, a } })
  end

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", x, y)
  title:SetText(BIT.L("Appearance"))
  y = y - 30

  -- Scope, raw role names and the font path live in this frame. It stays hidden
  -- until Advanced is opened, so the first screen is the everyday controls.
  local advanced = CreateFrame("Frame", nil, panel)
  advanced:Hide()
  panel.advanced = advanced
  local ax, ay = 12, -8
  local advancedButton
  advancedButton = BIT.UI.Button(panel, BIT.L("Advanced"), 160, function()
    panel:SetAdvanced(not panel.advancedOpen)
  end)
  advancedButton:SetPoint("TOPLEFT", x, y)
  y = y - 30
  controls.advancedButton = advancedButton

  local scopeButton
  local function setResetText(button, text)
    button:SetText(BIT.L(text))
    local label = button:GetFontString()
    if not label then return end
    local font, size, flags = label:GetFont()
    if not button.resetFontSize then button.resetFontSize = size end
    if font and button.resetFontSize then
      if label.SetWordWrap then label:SetWordWrap(false) end
      label:SetFont(font, button.resetFontSize, flags)
      local textWidth = label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth()
      local available = button:GetWidth() - 24
      if textWidth > available and available > 0 then
        label:SetFont(font, button.resetFontSize * available / textWidth, flags)
      end
    end
  end
  scopeButton = BIT.UI.Button(advanced, BIT.L("Editing: this module"), 300, function()
    scopeIsGlobal = not scopeIsGlobal
    scopeButton:SetText(BIT.L(scopeIsGlobal and "Editing: all modules" or "Editing: this module"))
    if controls.reset then
      setResetText(controls.reset, scopeIsGlobal and "Reset shared appearance (all modules)"
        or "Reset this module's appearance")
    end
    refreshPanel()
  end)
  scopeButton:SetPoint("TOPLEFT", ax, ay)
  ay = ay - 32
  controls.scope = scopeButton

  local paletteNote = advanced:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  paletteNote:SetPoint("TOPLEFT", ax, ay)
  paletteNote:SetText(BIT.L("Palette (arbitrary RGB)"))
  ay = ay - 24

  local showRgbFields

  -- Palette: a swatch per role; two columns.
  for i = 1, #roles do
    local role = roles[i]
    local swatch = CreateFrame("Button", nil, advanced)
    swatch:SetSize(18, 18)
    swatch:SetPoint("TOPLEFT", ax, ay)
    swatch.tex = swatch:CreateTexture(nil, "ARTWORK")
    swatch.tex:SetAllPoints()
    BIT.UI.RoundBorder(swatch, { 0.6, 0.6, 0.6, 0.65 })
    local label = advanced:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
    label:SetText(BIT.L(role))
    local function open()
      local style = currentStyle()
      local openedScope = scopeKey() -- fixed at opening, never at drag time
      local c = style.colors[role]
      local prior = priorColorWrite(openedScope, role)
      local last = { c[1], c[2], c[3], c[4] }
      local function commit(r, g, b, a)
        -- Native OKAY invokes both callbacks even when the user changed nothing.
        -- Preserve inheritance and avoid duplicate refreshes for the same colour.
        if math.abs(r - last[1]) < 0.000001 and math.abs(g - last[2]) < 0.000001
          and math.abs(b - last[3]) < 0.000001 and math.abs(a - last[4]) < 0.000001 then return end
        last = { r, g, b, a }
        Style.Set(openedScope, "colors", { [role] = { r, g, b, a } })
      end
      local function cancel(r, g, b, a)
        if prior then
          Style.Set(openedScope, "colors", { [role] = { r, g, b, a } }) -- back to the stored override
        else
          Style.RemoveColor(openedScope, role) -- back to no override
        end
      end
      local opened = openNativeColorPicker(commit, c[1], c[2], c[3], c[4], true, cancel)
      if not opened then
        showRgbFields(role)
      end
    end
    swatch:SetScript("OnClick", open)
    controls.swatches[role] = swatch
    if i % 2 == 0 then
      ay = ay - 24
      ax = 12
    else
      ax = 170
    end
  end
  if #roles % 2 == 1 then ay = ay - 24 end
  ax = 12

  -- Validated RGB edit fields, used only when the native picker is unavailable.
  local rgbRole
  local rgbFrame = CreateFrame("Frame", nil, advanced)
  rgbFrame:Hide()
  rgbFrame:SetSize(width - 24, 26)
  rgbFrame:SetPoint("TOPLEFT", ax, ay)
  local rgbTitle = rgbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rgbTitle:SetPoint("LEFT", 0, 0)
  local rgbBoxes = {}
  for i, name in ipairs({ "R", "G", "B", "A" }) do
    local box = CreateFrame("EditBox", nil, rgbFrame, "InputBoxTemplate")
    box:SetSize(48, 18)
    box:SetFont(DEFAULTS.font, 12, "")
    box:SetTextColor(1, 1, 1, 1)
    box:SetNumeric(true)
    box:SetAutoFocus(false)
    box:SetPoint("LEFT", rgbTitle, "RIGHT", 8 + (i - 1) * 54, 0)
    local boxLabel = rgbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    boxLabel:SetPoint("BOTTOM", box, "TOP", 0, 0)
    boxLabel:SetText(name)
    box:SetScript("OnEnterPressed", function()
      local vals = {}
      for j, n in ipairs({ "R", "G", "B", "A" }) do
        local num = tonumber(rgbBoxes[n]:GetText()) or 0
        vals[n] = math.max(0, math.min(255, math.floor(num + 0.5)))
      end
      if rgbRole then
        commitColor(rgbRole, vals.R / 255, vals.G / 255, vals.B / 255, vals.A / 255)
      end
    end)
    rgbBoxes[name] = box
  end
  controls.rgb.frame, controls.rgb.boxes = rgbFrame, rgbBoxes
    showRgbFields = function(role)
    local c = currentStyle().colors[role]
    rgbRole = role
    rgbTitle:SetText(string.format(BIT.L("RGB %s:"), BIT.L(role)))
    rgbBoxes.R:SetText(string.format("%d", math.floor(c[1] * 255 + 0.5)))
    rgbBoxes.G:SetText(string.format("%d", math.floor(c[2] * 255 + 0.5)))
    rgbBoxes.B:SetText(string.format("%d", math.floor(c[3] * 255 + 0.5)))
    rgbBoxes.A:SetText(string.format("%d", math.floor(c[4] * 255 + 0.5)))
    rgbFrame:Show()
    if panel.layout then panel.layout() end
  end
  ay = ay - 36
  if capabilities.font then
    local fontLabel = advanced:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", ax, ay)
    fontLabel:SetText(BIT.L("Font path:"))
    local fontBox = CreateFrame("EditBox", nil, advanced, "InputBoxTemplate")
    fontBox:SetSize(math.max(80, width - 180), 20)
    fontBox:SetFont(DEFAULTS.font, 12, "")
    fontBox:SetTextColor(1, 1, 1, 1)
    fontBox:SetAutoFocus(false)
    fontBox:SetPoint("LEFT", fontLabel, "RIGHT", 6, 0)
    fontBox:SetScript("OnEnterPressed", function()
      local text = fontBox:GetText() or ""
      if text ~= "" then commit("font", text) end
    end)
    ay = ay - 28
    controls.fontBox = fontBox
  end
  advanced:SetSize(width, -ay + 8)

  -- The shared rows (Core/LookRows.lua): the same slider, drop-down and check box as every module's own options.
  local function slider(label, minv, maxv, step, key, display, suffix)
    local row = BIT.Looks.Rows.Slider(panel, label, minv, maxv, step,
      function() return currentStyle()[key] end,
      function(v) commit(key, v) end, { display = display, suffix = suffix })
    row:SetPoint("TOPLEFT", x, y)
    y = y - row:GetHeight()
    controls.sliders[key] = row
  end
  local function percent(v) return math.floor(v * 100 + 0.5) .. "%" end

  if capabilities.opacity ~= false then
    slider("Opacity", 0, 1, 0.05, "opacity", percent)
  end

  if capabilities.shapes and #capabilities.shapes > 0 then
    local shapes = capabilities.shapes
    local list = {}
    for i = 1, #shapes do
      local id = shapes[i]
      list[i] = { id = id, label = id:sub(1, 1):upper() .. id:sub(2) }
    end
    local shapeRow = BIT.Looks.Rows.Choice(panel, "Shape", list,
      function() return currentStyle().shape end, function(id) commit("shape", id) end)
    shapeRow:SetPoint("TOPLEFT", x, y)
    y = y - shapeRow:GetHeight()
    controls.shape = shapeRow
  end

  if capabilities.border then slider("Border", 0, 16, 1, "border", nil, " px") end

  if capabilities.geometry then
    slider("Thickness", 1, 64, 1, "thickness", nil, " px")
    slider("Gap", 0, 32, 1, "gap", nil, " px")
    slider("Length", 1, 128, 1, "length", nil, " px")
  end

  if capabilities.scale then slider("Scale", 0.5, 3, 0.05, "scale", function(v) return string.format("%.2fx", v) end) end

  if capabilities.font then
    slider("Font size", 6, 48, 1, "fontSize", nil, " px")
    local outlineRow = BIT.Looks.Rows.Choice(panel, "Text outline", {
      { id = "NONE", label = "None" }, { id = "OUTLINE", label = "Outline" }, { id = "THICKOUTLINE", label = "Thick outline" },
    }, function() return currentStyle().outline end, function(id) commit("outline", id) end)
    outlineRow:SetPoint("TOPLEFT", x, y)
    y = y - outlineRow:GetHeight()
    controls.outline = outlineRow
  end

  -- the opacity slider is built above only when the capability allows it
  local motion = BIT.Looks.Rows.Check(panel, "Reduced motion",
    function() return currentStyle().reducedMotion end,
    function(v) commit("reducedMotion", v) end,
    { tooltip = "Limits the animations (pulses, glides, sweeps) to the calm ones." })
  motion:SetPoint("TOPLEFT", x, y)
  y = y - motion:GetHeight()
  controls.checks.reducedMotion = motion

  -- The Minimal preset is scope-aware: editing this module writes that module's
  -- effective defaults (product overlaid with its registered module defaults),
  -- editing all modules writes the shared product defaults only. A global preset
  -- therefore never leaks one module's palette into unrelated modules.
  local presetButton = BIT.UI.Button(panel, BIT.L("Minimal preset"), 160, function()
    local source = scopeIsGlobal and Style.Defaults or Style.GetDefaults(moduleName)
    commit("colors", source.colors)
    for key, v in pairs(source) do
      if key ~= "colors" then commit(key, v) end
    end
  end)
  presetButton:SetPoint("TOPLEFT", x, y)
  local resetButton = BIT.UI.Button(panel, BIT.L("Reset this module's appearance"), 300, function()
    Style.Reset(scopeKey())
  end)
  if width < 500 then
    resetButton:SetPoint("TOPLEFT", presetButton, "BOTTOMLEFT", 0, -6)
    resetButton:SetWidth(width - 24)
    y = y - 62
  else
    resetButton:SetPoint("LEFT", presetButton, "RIGHT", 10, 0)
    resetButton:SetWidth(width - presetButton:GetWidth() - 34)
    y = y - 34
  end
  setResetText(resetButton, "Reset this module's appearance")
  controls.preset, controls.reset = presetButton, resetButton

  local resetHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  resetHint:SetPoint("TOPLEFT", x, y)
  resetHint:SetText(BIT.L("Reset changes only the appearance: gameplay settings, sounds, anchors and "
    .. "learned values stay."))
  resetHint:SetWidth(width - 24)
  resetHint:SetWordWrap(true)
  y = y - math.max(24, (resetHint:GetStringHeight() or 14) + 10)
  controls.resetHint = resetHint

  -- The module's real renderer also owns the appearance sample, including while off.
  local tab = BIT.tabs and BIT.tabs[moduleName]
  local sample, renderSample
  local sampleTop, sampleHeight = y, 96
  if tab and type(tab.buildPreview) == "function" and type(tab.previewRender) == "function" then
    local ok, scene = pcall(tab.buildPreview, panel)
    if ok and type(scene) == "table" and type(scene.SetPoint) == "function" then
      sample = scene
    else
      BIT.Say("the " .. moduleName .. " appearance sample could not be built: " .. tostring(scene))
    end
  end
  if sample then
    sample:SetPoint("TOPLEFT", x, sampleTop)
    renderSample = function()
      local ok, err = pcall(tab.previewRender, sample, Style.Resolve(moduleName, legacy))
      if not ok then
        BIT.Say("the " .. moduleName .. " appearance sample could not render: " .. tostring(err))
        return
      end
      local fit = math.min(1, (width - 24) / math.max(1, sample:GetWidth()))
      sample:SetScale(fit)
      sample:ClearAllPoints()
      sample:SetPoint("TOPLEFT", panel, "TOPLEFT", x / fit, sampleTop / fit) -- offsets scale with the frame
      local height = sample:GetHeight() * fit + 12
      if height ~= sampleHeight then
        sampleHeight = height
        if panel.layout then panel.layout() end
      end
    end
  else
    sample = CreateFrame("Frame", nil, panel)
    sample:SetPoint("TOPLEFT", x, sampleTop)
    sample:SetSize(width - 24, 96)
    local sampleTitle = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sampleTitle:SetPoint("TOPLEFT", 0, 0)
    sampleTitle:SetText(BIT.L("Sample: fictitious data, not the live game"))
    sample.markers = Style.CreateMarkers(sample, SAMPLE_MARKERS_TOTAL)
    sample.markers:SetPoint("TOPLEFT", 0, -22)
    sample.bar = CreateFrame("StatusBar", nil, sample)
    sample.bar:SetSize(140, 14)
    sample.bar:SetMinMaxValues(0, SAMPLE_BAR_MAX)
    sample.bar:SetValue(SAMPLE_BAR_VALUE)
    sample.barLabel = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sample.barLabel:SetPoint("LEFT", sample.bar, "RIGHT", 8, 0)
    sample.textLine = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.sampleMarkers, panel.sampleBar, panel.sampleText = sample.markers, sample.bar, sample.textLine
    renderSample = function(style)
      Style.RenderMarkers(sample.markers, style, SAMPLE_MARKERS_ACTIVE, SAMPLE_MARKERS_TOTAL, "accent")
      Style.ApplyBar(sample.bar, style, "absorb")
      sample.bar:SetPoint("TOPLEFT", 0, -34 - sample.markers:GetHeight())
      sample.barLabel:SetText(string.format("%d/%d", SAMPLE_BAR_VALUE, SAMPLE_BAR_MAX))
      Style.ApplyText(sample.barLabel, style, "text")
      sample.textLine:SetPoint("TOPLEFT", sample.bar, "BOTTOMLEFT", 0, -10)
      sample.textLine:SetText(BIT.L(SAMPLE_TEXT))
      Style.ApplyText(sample.textLine, style, "text")
      sampleHeight = 70 + sample.markers:GetHeight() + style.fontSize
      if panel.layout then panel.layout() end
    end
  end
  panel.sample = sample

  refreshPanel = function()
    local style = currentStyle()
    for key, holder in pairs(controls.sliders) do holder:Refresh() end
    if controls.fontBox then controls.fontBox:SetText(style.font) end
    for role, swatch in pairs(controls.swatches) do
      local c = style.colors[role]
      swatch.tex:SetColorTexture(c[1], c[2], c[3], c[4] * style.opacity)
    end
    if controls.shape then controls.shape:Refresh() end
    if controls.outline then controls.outline:Refresh() end
    if controls.checks.reducedMotion then controls.checks.reducedMotion:Refresh() end
    renderSample(style)
  end
  panel.Refresh = refreshPanel
  panel:HookScript("OnShow", refreshPanel)

  local unsubscribe = Style.Subscribe("*", function(scope)
    if scope == moduleName or scope == "*" then
      refreshPanel()
      if refresh then
        local ok, err = pcall(refresh)
        if not ok then BIT.Say("the appearance preview could not refresh: " .. tostring(err)) end
      end
    end
  end)
  panel.Release = unsubscribe

  refreshPanel()
  -- The sample hangs below the last control; keep it inside the panel, and grow
  -- further only while Advanced is open. onLayout lets the /upt scroll follow.
  local function layoutPanel()
    local bottom = sampleTop - sampleHeight
    advanced:ClearAllPoints()
    advanced:SetPoint("TOPLEFT", 0, bottom)
    local h = -bottom + 16
    if panel.advancedOpen then h = h + advanced:GetHeight() end
    panel:SetSize(width, h)
    if controls.advancedButton then
      controls.advancedButton:SetText(BIT.L(panel.advancedOpen and "Hide advanced" or "Advanced"))
    end
    if type(panel.onLayout) == "function" then panel.onLayout() end
  end
  function panel:SetAdvanced(open)
    self.advancedOpen = open and true or false
    if self.advancedOpen then advanced:Show() else advanced:Hide() end
    layoutPanel()
  end
  panel.layout = layoutPanel
  layoutPanel()
  return panel
end
