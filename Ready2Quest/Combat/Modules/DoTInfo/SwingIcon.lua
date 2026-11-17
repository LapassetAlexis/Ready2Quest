-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- DoTInfo: the weapon icon, the second kill icon.
-- Copyright (c) 2026 Rogerio Camorim. GPL-3.0-or-later, see LICENSE.
--
-- The kill icon (a skull, by default) means the DoTs alone will kill the mob. With "Count one weapon hit" on, a weapon
-- icon (the icon of the Attack ability, or of Auto Shot / Shoot when the best hit is a ranged one) shows where the skull
-- would, when the DoTs plus one average weapon hit kill but the DoTs alone do not yet. The skull used to light for both,
-- so it no longer said which.
--
-- Health is secret in combat, so, like the skull (Core.lua), the weapon icon is lit by a StatusBar the widget compares
-- with the health: its value is the DoTs plus the swing, the skull bar's the DoTs alone. The icon rides the end of the
-- weapon bar's fill, inside a clipping frame that reaches from the end of the skull bar's fill to the end of the weapon
-- bar's fill (anchors to the two fill textures, so the client does the comparing): once the skull's fill has reached the
-- window the frame lies outside it and the weapon icon is gone, and while the DoTs are far short of lethal the swing is
-- too. Everything follows the skull's window and bar by anchors (position, size, show and hide), so a host (the target
-- frame, a nameplate, the focus frame) only creates it, styles it and feeds it a number.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local SwingIcon = {}
ns.SwingIcon = SwingIcon

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FALLBACK = "Interface\\Icons\\Ability_SteelMelee"

local function secret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, s = pcall(issecretvalue, v)
  return ok and s == true
end

local function textureOf(spellID)
  local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  if type(get) ~= "function" then return nil end
  local ok, texture = pcall(get, spellID)
  if ok and texture ~= nil and not secret(texture) then return texture end
  return nil
end

-- Whether the best weapon hit is a ranged one (SpellDamageInfo reads the character sheet).
local function rangedSwing()
  local sdi = BIT.modules and BIT.modules.SpellDamageInfo
  if type(sdi) ~= "table" or type(sdi.SwingIsRanged) ~= "function" then return false end
  local ok, ranged = pcall(sdi.SwingIsRanged)
  return ok and ranged == true
end

-- The picture: the melee Attack's, or for a ranged hit Auto Shot's (hunters) or Shoot's (wands).
local function pictureFor(ranged)
  if ranged then
    local _, _, class = pcall(UnitClass, "player")
    local first = textureOf(class == "HUNTER" and 75 or 5019)
    if first then return first end
  end
  return textureOf(6603) or textureOf(88163) or FALLBACK
end

-- window: the skull's clipping window; bar: its invisible StatusBar (a very long bar whose fill ends at the window's right
-- edge once the value reaches the health). Returns the object the other functions take.
function SwingIcon.New(window, bar)
  local o = { ranged = false }
  o.frame = CreateFrame("Frame", nil, window)
  o.frame:SetAllPoints(window)
  o.bar = CreateFrame("StatusBar", nil, o.frame)
  o.bar:SetPoint("TOPLEFT", bar, "TOPLEFT")
  o.bar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
  o.bar:SetStatusBarTexture(WHITE)
  o.bar:SetStatusBarColor(0, 0, 0, 0)
  o.clip = CreateFrame("Frame", nil, o.frame)
  o.clip:SetClipsChildren(true)
  o.clip:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
  o.clip:SetPoint("BOTTOMRIGHT", o.bar:GetStatusBarTexture(), "BOTTOMRIGHT")
  o.icon = o.clip:CreateTexture(nil, "OVERLAY")
  o.icon:SetPoint("RIGHT", o.bar:GetStatusBarTexture(), "RIGHT")
  o.icon:SetTexture(pictureFor(false))
  o.frame:Hide()
  return o
end

-- size: the skull icon's size; enabled: "Count one weapon hit".
function SwingIcon.Style(o, size, enabled)
  if not o then return end
  o.icon:SetSize(size, size)
  o.frame:SetShown(enabled and true or false)
end

-- health: the StatusBar's maximum (secret in combat, plain in the options preview); value: the DoTs plus the swing
-- (the skull bar gets the DoTs alone). Also notices a change between a melee and a ranged best hit.
local function draw(o, health, value)
  local ranged = rangedSwing()
  if ranged ~= o.ranged then
    o.ranged = ranged
    o.icon:SetTexture(pictureFor(ranged))
  end
  o.bar:SetMinMaxValues(0, health)
  o.bar:SetValue(value)
end

-- Called from inside the callers' protected drawing of the DoT marker: an error here must cost only the weapon icon,
-- never the marker (a failed draw hides the marker silently), so it is caught here and logged once.
function SwingIcon.Draw(o, health, value)
  if not o then return end
  local ok, err = pcall(draw, o, health, value)
  if not ok and not o.failed then
    o.failed = true
    if ns.trace then ns.trace("ERROR in weapon icon: " .. tostring(err)) end
  end
end
