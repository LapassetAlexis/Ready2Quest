-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Shared round markers for range bands and native resource StatusBars.
-- Counts belong to callers; only the native bars receive secret resource values.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Orbs = {}
BIT.Orbs = Orbs
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DIR = "Interface\\AddOns\\Ready2Quest\\Combat\\Modules\\ResourceDing\\Textures\\"
local ORB, RING, ORB_DARK, GLOW = DIR .. "ComboOrb", DIR .. "ComboRing", DIR .. "ComboOrbDark", DIR .. "ComboGlow"

function Orbs.Layout(dot, border)
  border = border or 1
  if type(dot) ~= "table" then return end
  if dot.border ~= nil and type(dot.border.ClearAllPoints) == "function" then
    dot.border:ClearAllPoints()
  end
  if dot.border ~= nil and type(dot.border.SetPoint) == "function" then
    dot.border:SetPoint("TOPLEFT", dot, "TOPLEFT", -border, border)
    dot.border:SetPoint("BOTTOMRIGHT", dot, "BOTTOMRIGHT", border, -border)
  end
  if dot.back ~= nil and type(dot.back.ClearAllPoints) == "function" then
    dot.back:ClearAllPoints()
  end
  if dot.back ~= nil and type(dot.back.SetAllPoints) == "function" then
    dot.back:SetAllPoints(dot)
  end
  -- Keep the halo in sync in previews as well as the live display.
  if dot.glow then dot.glow:SetSize(dot:GetWidth() * 1.9, dot:GetHeight() * 1.9) end
  if dot.glow ~= nil and type(dot.glow.ClearAllPoints) == "function" then
    dot.glow:ClearAllPoints()
    if type(dot.glow.SetPoint) == "function" then dot.glow:SetPoint("CENTER", dot, "CENTER") end
  end
  -- The metal bezel rides the overlay frame: it must stay above the fill and above the
  -- green full-state disc.
  local ring = type(dot.overlay) == "table" and dot.overlay.ring or nil
  if ring ~= nil and type(ring.ClearAllPoints) == "function" then
    ring:ClearAllPoints()
    if type(ring.SetAllPoints) == "function" then ring:SetAllPoints(dot.overlay) end
  end
end

function Orbs.Paint(dot, color, opacity, fullColor)
  opacity = opacity or 1
  dot.back:SetVertexColor(1, 1, 1, 0.9 * opacity)
  dot.border:SetVertexColor(0, 0, 0, 0.9 * opacity)
  dot:SetStatusBarColor(color[1], color[2], color[3], color[4])
  if fullColor then
    dot.overlay:SetStatusBarColor(fullColor[1], fullColor[2], fullColor[3], fullColor[4])
  end
  dot.overlay.ring:SetVertexColor(1, 1, 1, opacity)
  dot.glow:SetVertexColor(1, 1, 1, opacity)
end

function Orbs.Create(parent)
  local dot = CreateFrame("StatusBar", nil, parent)
  -- The halo for the newest point sits behind everything; the dark empty centre over it,
  -- then the outer black rim; the glossy fill is the bar's own texture, and the metal
  -- bezel lives on the overlay frame so it stays above the fill AND the full-state green.
  dot.glow = dot:CreateTexture(nil, "BACKGROUND", nil, -1)
  dot.glow:SetTexture(GLOW)
  dot.border = dot:CreateTexture(nil, "BACKGROUND", nil, 0)
  dot.border:SetTexture(CIRCLE)
  dot.border:SetVertexColor(0, 0, 0, 0.9)
  dot.back = dot:CreateTexture(nil, "BACKGROUND", nil, 1)
  dot.back:SetTexture(ORB_DARK)
  dot.back:SetVertexColor(1, 1, 1, 0.9)
  dot:SetStatusBarTexture(ORB)
  -- The secret-safe full-bar overlay: the same round mask in full green, one level above
  -- the dot's own fill. Its range spans the whole row and its value is the raw count, so
  -- the native client -- never this code -- shows it only at maximum, even when the count
  -- itself is a secret no Lua comparison may touch.
  local overlay = CreateFrame("StatusBar", nil, dot)
  overlay:SetStatusBarTexture(ORB)
  overlay.ring = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
  overlay.ring:SetTexture(RING)
  overlay.ring:SetVertexColor(1, 1, 1, 1)
  if type(dot.GetFrameLevel) == "function" and type(overlay.SetFrameLevel) == "function" then
    overlay:SetFrameLevel(dot:GetFrameLevel() + 1)
  end
  overlay:SetAllPoints(dot)
  dot.overlay = overlay
  -- Corner clipping the client itself enforces: where it offers mask textures
  -- (UnitFrame/EvokerEbonMightBar pattern), the overlay fill is clipped to the same
  -- round asset, so the green full-bar mark stays a circle -- never a stretched oval
  -- or a partially rounded fill gap. One mask only, no union; every anchor is the
  -- plain full slot, and the count still reaches only the native SetValue below.
  -- Clients without the mask API keep the round asset as the fill, like the dots.
  local fill = type(overlay.GetStatusBarTexture) == "function" and overlay:GetStatusBarTexture() or nil
  if type(overlay.CreateMaskTexture) == "function" and type(fill) == "table"
      and type(fill.AddMaskTexture) == "function" then
    local mask = overlay:CreateMaskTexture()
    if type(mask) == "table" then
      if type(mask.SetTexture) == "function" then
        pcall(mask.SetTexture, mask, CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      end
      if type(mask.SetWrapMode) == "function" then
        pcall(mask.SetWrapMode, mask, "CLAMPTOBLACK", "ADDITIVE")
      end
      if type(mask.SetAllPoints) == "function" then mask:SetAllPoints(overlay) end
      fill:AddMaskTexture(mask)
      overlay.circleMask = mask
    end
  end
  dot.glow:Hide()
  Orbs.Layout(dot)
  return dot
end
