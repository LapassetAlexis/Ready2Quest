-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: mock game frames shared by the settings previews.
-- Every module's live preview shows its marks on the world's own furniture -- the target
-- frame, an enemy nameplate, the player frame -- rebuilt from the client's atlases at
-- Blizzard's offsets, exactly as the DoT preview does, with flat fallbacks where an atlas
-- is missing. One kit, so every preview reads alike. Nothing here reads units, saved
-- settings or the game state; the callers paint their own marks onto what it returns.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.UI = BIT.UI or {}
local P = {}
BIT.UI.Preview = P

local WHITE = "Interface\\Buttons\\WHITE8X8"
P.WHITE = WHITE

function P.fontOr(name, fallback)
  return _G[name] and name or fallback
end

-- Forever ships its own bronze ("-c60") versions of the modern HUD art: those first, else
-- the plain atlas (Retail). false when neither exists, so the caller keeps a plain fallback.
function P.setAtlas(texture, name)
  if type(texture) ~= "table" or type(texture.SetAtlas) ~= "function" then return false end
  if not (C_Texture and type(C_Texture.GetAtlasInfo) == "function") then return false end
  for _, candidate in ipairs({ name .. "-c60", name }) do
    local ok, info = pcall(C_Texture.GetAtlasInfo, candidate)
    if ok and info then
      if pcall(texture.SetAtlas, texture, candidate) then return true end
    end
  end
  return false
end

-- Vertical gradient (bottom colour, top colour); a flat colour where the client has no
-- gradient API.
function P.gradient(texture, bottom, top)
  texture:SetTexture(WHITE)
  if CreateColor and pcall(texture.SetGradient, texture, "VERTICAL",
      CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]), CreateColor(top[1], top[2], top[3], top[4])) then
    return
  end
  texture:SetVertexColor(bottom[1], bottom[2], bottom[3], (bottom[4] + top[4]) / 2)
end

-- Blizzard's unit frames clip absorb and heal-prediction fills to the bar's own shape with the
-- HealthBarMask of the frame that holds the bar. Our overlays are plain full-size children of
-- the bar, so they take the same mask; without it a fill spills above and below the visible
-- bar (the shield hatching escaped the player frame's health bar).
local BarMask = {}
BIT.UI.BarMask = BarMask

function BarMask.Find(healthBar)
  local ok, mask = pcall(function()
    local parent = healthBar:GetParent()
    return parent and parent.HealthBarMask or nil
  end)
  if ok and type(mask) == "table" and type(mask.GetObjectType) == "function" then return mask end
  return nil
end

-- Put the health bar's mask on a fill texture, replacing the mask it took from a previous bar.
-- on = false only removes it. Safe on a texture without mask support.
function BarMask.Apply(fill, healthBar, on)
  if type(fill) ~= "table" or type(fill.AddMaskTexture) ~= "function" then return end
  if fill.uptMask then
    pcall(fill.RemoveMaskTexture, fill, fill.uptMask)
    fill.uptMask = nil
  end
  fill.uptHost = on and healthBar or nil -- remembered, so a repaint can put the mask back (RefreshTexture)
  if not on then return end
  local mask = BarMask.Find(healthBar)
  if mask and pcall(fill.AddMaskTexture, fill, mask) then fill.uptMask = mask end
end

-- Whatever repaints a masked texture (SetTexture, SetStatusBarTexture) may drop the mask or hand out a new texture:
-- call this after every repaint and the fill is cut to the bar's shape again.
function BarMask.RefreshTexture(texture)
  local host = type(texture) == "table" and texture.uptHost
  if host then BarMask.Apply(texture, host, true) end
end

-- The same for a status bar's fill: ApplyToBar remembers the health bar, Refresh re-applies to the bar's current texture.
function BarMask.ApplyToBar(bar, healthBar, on)
  if type(bar) ~= "table" or type(bar.GetStatusBarTexture) ~= "function" then return end
  bar.uptMaskHost = on and healthBar or nil
  BarMask.Apply(bar:GetStatusBarTexture(), healthBar, on)
end

function BarMask.Refresh(bar)
  local host = type(bar) == "table" and bar.uptMaskHost
  if host and type(bar.GetStatusBarTexture) == "function" then BarMask.Apply(bar:GetStatusBarTexture(), host, true) end
end

-- The mask a mock frame carries for its own health bar (the same atlas and offset as the game's).
local function addHealthMask(mock, healthBar, atlas, x, y)
  if type(mock.CreateMaskTexture) ~= "function" or not (C_Texture and type(C_Texture.GetAtlasInfo) == "function") then
    return
  end
  for _, candidate in ipairs({ atlas .. "-c60", atlas }) do
    local ok, info = pcall(C_Texture.GetAtlasInfo, candidate)
    if ok and info then
      local mask = mock:CreateMaskTexture()
      if pcall(mask.SetAtlas, mask, candidate) then
        mask:SetSize(info.width, info.height)
        mask:SetPoint("TOPLEFT", healthBar, "TOPLEFT", x, y)
        mock.HealthBarMask = mask
        return
      end
    end
  end
end

-- A patch of dusky world behind the mock frames, so they read as the game's own HUD.
function P.Scene(parent, width, height)
  local scene = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  scene:SetSize(width, height)
  scene:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
  scene:SetBackdropBorderColor(0, 0, 0, 1)
  local ground = scene:CreateTexture(nil, "BACKGROUND", nil, -8)
  ground:SetPoint("TOPLEFT", 1, -1)
  ground:SetPoint("BOTTOMRIGHT", -1, 1)
  ground:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
  ground:SetTexCoord(0, 0.26, 0, 0.18) -- about 1:1 texels on the patch
  ground:SetVertexColor(0.75, 0.8, 0.75)
  local sky = scene:CreateTexture(nil, "BACKGROUND", nil, -7)
  sky:SetAllPoints(ground)
  P.gradient(sky, { 0.055, 0.08, 0.04, 0.25 }, { 0.07, 0.1, 0.15, 0.6 })
  local topShade = scene:CreateTexture(nil, "BACKGROUND", nil, -6)
  topShade:SetPoint("TOPLEFT", ground, "TOPLEFT")
  topShade:SetPoint("TOPRIGHT", ground, "TOPRIGHT")
  topShade:SetHeight(26)
  P.gradient(topShade, { 0, 0, 0, 0 }, { 0, 0, 0, 0.6 })
  local bottomShade = scene:CreateTexture(nil, "BACKGROUND", nil, -6)
  bottomShade:SetPoint("BOTTOMLEFT", ground, "BOTTOMLEFT")
  bottomShade:SetPoint("BOTTOMRIGHT", ground, "BOTTOMRIGHT")
  bottomShade:SetHeight(30)
  P.gradient(bottomShade, { 0, 0, 0, 0.65 }, { 0, 0, 0, 0 })
  return scene
end

-- Forever's own target frame (TargetFrameTemplate, 232 x 100) rebuilt from its atlases at
-- Blizzard's offsets. opts: name, level, health, text (bar numbers, default true),
-- layerFrame (the frame the marks draw on, for host.layerFrame).
function P.TargetFrame(parent, opts)
  opts = opts or {}
  local name = opts.name or "Murloc Raider"
  local level = opts.level or "12"
  local health = tonumber(opts.health) or 72

  local mock = CreateFrame("Frame", nil, parent)
  mock:SetSize(232, 100)

  local portrait = mock:CreateTexture(nil, "BACKGROUND", nil, 1)
  portrait:SetSize(58, 58)
  portrait:SetPoint("TOPRIGHT", mock, "TOPRIGHT", -26, -19)
  portrait:SetTexture(opts.portrait or "Interface\\Icons\\Achievement_Reputation_MurlocOracle")
  portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- the icon's own border would show at the circle's edge
  local mask = mock:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(portrait)
  portrait:AddMaskTexture(mask)

  local frameArt = mock:CreateTexture(nil, "BACKGROUND", nil, 2)
  frameArt:SetSize(192, 67)
  frameArt:SetPoint("TOPLEFT", mock, "TOPLEFT", 20, -16)
  local hasFrameArt = P.setAtlas(frameArt, "UI-HUD-UnitFrame-Target-PortraitOn")
  if not hasFrameArt then
    frameArt:ClearAllPoints()
    frameArt:SetPoint("TOPLEFT", mock, "TOPLEFT", 18, -22)
    frameArt:SetSize(134, 42)
    frameArt:SetColorTexture(0, 0, 0, 0.55)
  end

  local nameBand = mock:CreateTexture(nil, "BORDER")
  nameBand:SetSize(135, 18)
  nameBand:SetPoint("TOPLEFT", mock, "TOPLEFT", 22, -25)
  if P.setAtlas(nameBand, "UI-HUD-UnitFrame-Target-PortraitOn-Type") then
    nameBand:SetVertexColor(1, 0, 0) -- hostile, as UnitSelectionColor colours it
  else
    nameBand:Hide()
  end

  local nameText = mock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameText:SetSize(117, 12)
  nameText:SetPoint("TOPLEFT", mock, "TOPLEFT", 24, -26)
  nameText:SetJustifyH("LEFT")
  nameText:SetText(name)

  local levelCircle = mock:CreateTexture(nil, "OVERLAY")
  levelCircle:SetSize(39, 39)
  levelCircle:SetPoint("BOTTOMRIGHT", mock, "BOTTOMRIGHT", -13, 7)
  local levelText = mock:CreateFontString(nil, "OVERLAY", P.fontOr("WhiteLargeNumberFont", "GameFontNormal"))
  levelText:SetDrawLayer("OVERLAY", 2)
  levelText:SetPoint("CENTER", levelCircle, "CENTER", 0, -0.5)
  levelText:SetText(level)
  levelText:SetTextColor(1, 0.82, 0) -- same-level ("fair") difficulty colour
  if not P.setAtlas(levelCircle, "UI-HUD-UnitFrame-SmallCircle") then
    levelCircle:Hide()
    levelText:Hide()
  end

  local healthBar = CreateFrame("StatusBar", nil, mock)
  healthBar:SetSize(126, 20)
  healthBar:SetPoint("TOPLEFT", mock, "TOPLEFT", 22, -39)
  healthBar:SetMinMaxValues(0, 100)
  healthBar:SetValue(health)
  healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  if P.setAtlas(healthBar:GetStatusBarTexture(), "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health") then
    healthBar:SetStatusBarColor(1, 1, 1)
  else
    healthBar:SetStatusBarColor(0.1, 0.8, 0.1)
  end
  if not hasFrameArt then
    local healthBack = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBack:SetAllPoints()
    healthBack:SetColorTexture(0.25, 0.08, 0.08, 1)
  end
  addHealthMask(mock, healthBar, "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Mask", -1, 6)
  local out = { frame = mock, healthBar = healthBar, bar = healthBar, portrait = portrait, name = nameText,
    level = levelText, host = { healthBar = healthBar, portrait = portrait, layerFrame = opts.layerFrame } }
  if opts.text ~= false then
    local barText = P.fontOr("TextStatusBarText", "GameFontHighlightSmall")
    out.healthPercent = healthBar:CreateFontString(nil, "OVERLAY", barText)
    out.healthPercent:SetPoint("LEFT", healthBar, "LEFT", 3, 0)
    out.healthPercent:SetText(string.format("%d%%", math.floor(health + 0.5)))
    out.healthValue = healthBar:CreateFontString(nil, "OVERLAY", barText)
    out.healthValue:SetPoint("RIGHT", healthBar, "RIGHT", -3, 0)
    out.healthValue:SetText("88")
  end
  return out
end

-- The player frame's own art (Player-PortraitOn atlases), the same 232 x 100 layout. The
-- player frame prints no level circle; the name sits on the bar. opts: name, health, text.
function P.PlayerFrame(parent, opts)
  opts = opts or {}
  local name = opts.name or "You"
  local health = tonumber(opts.health) or 100

  local mock = CreateFrame("Frame", nil, parent)
  mock:SetSize(232, 100)

  -- The player frame is the target frame mirrored: the portrait sits on the LEFT (its atlas
  -- art is drawn for that), the name band and the health bar on the right half.
  local portrait = mock:CreateTexture(nil, "BACKGROUND", nil, 1)
  portrait:SetSize(58, 58)
  portrait:SetPoint("TOPLEFT", mock, "TOPLEFT", 26, -19)
  portrait:SetTexture(opts.portrait or "Interface\\Icons\\Achievement_Reputation_MurlocOracle")
  portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local mask = mock:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(portrait)
  portrait:AddMaskTexture(mask)

  local frameArt = mock:CreateTexture(nil, "BACKGROUND", nil, 2)
  frameArt:SetSize(192, 67)
  frameArt:SetPoint("TOPLEFT", mock, "TOPLEFT", 20, -16)
  local hasFrameArt = P.setAtlas(frameArt, "UI-HUD-UnitFrame-Player-PortraitOn")
  if not hasFrameArt then
    frameArt:ClearAllPoints()
    frameArt:SetPoint("TOPRIGHT", mock, "TOPRIGHT", -18, -22)
    frameArt:SetSize(134, 42)
    frameArt:SetColorTexture(0, 0, 0, 0.55)
  end

  local nameBand = mock:CreateTexture(nil, "BORDER")
  nameBand:SetSize(135, 18)
  nameBand:SetPoint("TOPLEFT", mock, "TOPLEFT", 75, -25)
  if not P.setAtlas(nameBand, "UI-HUD-UnitFrame-Player-PortraitOn-Type") then
    nameBand:Hide()
  end
  local nameText = mock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameText:SetSize(117, 12)
  nameText:SetPoint("TOPLEFT", mock, "TOPLEFT", 77, -26)
  nameText:SetJustifyH("LEFT")
  nameText:SetText(name)

  local healthBar = CreateFrame("StatusBar", nil, mock)
  healthBar:SetSize(126, 20)
  healthBar:SetPoint("TOPLEFT", mock, "TOPLEFT", 84, -39)
  healthBar:SetMinMaxValues(0, 100)
  healthBar:SetValue(health)
  healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  if P.setAtlas(healthBar:GetStatusBarTexture(), "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health") then
    healthBar:SetStatusBarColor(1, 1, 1)
  else
    healthBar:SetStatusBarColor(0.12, 0.85, 0.12)
  end
  if not hasFrameArt then
    local healthBack = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBack:SetAllPoints()
    healthBack:SetColorTexture(0.05, 0.2, 0.05, 1)
  end
  addHealthMask(mock, healthBar, "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Mask", -2, 6)
  local out = { frame = mock, healthBar = healthBar, bar = healthBar, portrait = portrait, name = nameText,
    host = { healthBar = healthBar, portrait = portrait, layerFrame = opts.layerFrame } }
  if opts.text ~= false then
    local barText = P.fontOr("TextStatusBarText", "GameFontHighlightSmall")
    out.healthPercent = healthBar:CreateFontString(nil, "OVERLAY", barText)
    out.healthPercent:SetPoint("LEFT", healthBar, "LEFT", 3, 0)
    out.healthPercent:SetText(string.format("%d%%", math.floor(health + 0.5)))
    out.healthValue = healthBar:CreateFontString(nil, "OVERLAY", barText)
    out.healthValue:SetPoint("RIGHT", healthBar, "RIGHT", -3, 0)
    out.healthValue:SetText("100")
  end
  return out
end

-- Forever's default ("Thin") enemy nameplate: a bar with the level badge, the level left
-- of it and the name centred above. opts: width (190, the bar is width - 57 wide), name,
-- level, health, hostile. Drawn on by the real nameplate code.
function P.Nameplate(parent, opts)
  opts = opts or {}
  local width = tonumber(opts.width) or 190
  local name = opts.name or "Murloc Raider"
  local level = opts.level or "12"
  local health = tonumber(opts.health) or 72
  local hostile = opts.hostile ~= false

  local plate = CreateFrame("Frame", nil, parent)
  plate:SetSize(width, 36)
  local bar = CreateFrame("StatusBar", nil, plate)
  bar:SetSize(width - 57, 13)
  bar:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", 12, 6)
  bar:SetMinMaxValues(0, 100)
  bar:SetValue(health)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  if P.setAtlas(bar:GetStatusBarTexture(), "UI-HUD-CoolDownManager-Bar") then
    if hostile then bar:SetStatusBarColor(1, 0, 0) else bar:SetStatusBarColor(0.2, 1, 0.2) end
  elseif hostile then
    bar:SetStatusBarColor(0.85, 0.1, 0.1)
  else
    bar:SetStatusBarColor(0.12, 0.85, 0.12)
  end
  local back = plate:CreateTexture(nil, "BACKGROUND")
  back:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
  back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
  if not P.setAtlas(back, "UI-HUD-CoolDownManager-Bar-BG") then
    back:ClearAllPoints()
    back:SetAllPoints(bar)
    back:SetColorTexture(0.1, 0.02, 0.02, 1)
  end
  -- It is the target's plate: the yellow selection border (Forever: vertex white).
  local selected = bar:CreateTexture(nil, "OVERLAY")
  selected:SetPoint("TOPLEFT", back, "TOPLEFT", -3, 2)
  selected:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", 0, 2)
  if P.setAtlas(selected, "UI-HUD-CoolDownManager-Selected-yellow") then
    selected:SetVertexColor(1, 1, 1, 0.9)
  else
    selected:Hide()
  end
  local levelBadge = plate:CreateTexture(nil, "ARTWORK")
  levelBadge:SetSize(28, 16)
  levelBadge:SetPoint("LEFT", bar, "RIGHT", 5, 0)
  local levelText = plate:CreateFontString(nil, "OVERLAY", P.fontOr("SystemFont_NamePlateLevel", "GameFontNormalSmall"))
  levelText:SetPoint("CENTER", levelBadge, "CENTER")
  levelText:SetText(level)
  levelText:SetTextColor(1, 0.82, 0)
  if not P.setAtlas(levelBadge, "UI-HUD-Nameplates-LevelIndicator") then
    levelBadge:Hide()
    levelText:Hide()
  end
  local nameText = plate:CreateFontString(nil, "OVERLAY",
    P.fontOr("SystemFont_NamePlate_Outlined", "GameFontHighlightSmallOutline"))
  nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 6) -- clear of the target border
  nameText:SetPoint("RIGHT", levelBadge, "RIGHT")
  nameText:SetJustifyH("CENTER")
  nameText:SetText(name)
  if hostile then nameText:SetTextColor(1, 0.13, 0.13) else nameText:SetTextColor(0.2, 1, 0.2) end
  return { frame = plate, bar = bar, back = back, selected = selected, name = nameText,
    levelBadge = levelBadge, level = levelText }
end

-- A compact party/raid bar: the name centred over a small bar, close to a compact unit
-- frame. opts: width (120), name, health, color.
function P.PartyBar(parent, opts)
  opts = opts or {}
  local width = tonumber(opts.width) or 120
  local health = tonumber(opts.health) or 80
  local color = opts.color or { 0.12, 0.85, 0.12 }
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, 30)
  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetSize(width, 14)
  bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  bar:SetMinMaxValues(0, 100)
  bar:SetValue(health)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(color[1], color[2], color[3])
  local back = bar:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.05, 0.05, 0.05, 1)
  local border = frame:CreateTexture(nil, "OVERLAY")
  border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
  border:SetColorTexture(0, 0, 0, 0.8)
  border:SetDrawLayer("OVERLAY", -1)
  local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameText:SetPoint("BOTTOM", bar, "TOP", 0, 3)
  nameText:SetText(opts.name or "Kaya")
  nameText:SetTextColor(0.65, 0.8, 1)
  return { frame = frame, bar = bar, name = nameText }
end

return P
