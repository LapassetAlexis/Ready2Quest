-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- ElvUI: gives the marks that sit on a health bar (DoT kill marks, shields, heals) ElvUI's own
-- unit frames and nameplates, which replace Blizzard's. Hooks into Core/PlateLayout.lua.
-- Copyright (c) 2026 Rogerio Camorim. GPL-3.0-or-later, see LICENSE.
--
-- ElvUI's frames (from its source): ElvUF_Player / ElvUF_Target / ElvUF_Focus, with the bar at .Health and the
-- portrait at .Portrait3D or .Portrait2D; a nameplate is plate.unitFrame (it has UpdateAllElements, Plater's has
-- none) with the bar at .Health.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Plate = BIT.Plate
local read = Plate.Read

-- A unit frame only counts while it is on screen: without a target it is hidden, and Blizzard's frame answers.
Plate.RegisterUnitFrameSource(function(_, part)
  local elv = type(ElvUI) == "table" and _G["ElvUF_" .. part]
  if type(elv) ~= "table" or read(elv.IsForbidden, elv) == true or read(elv.IsVisible, elv) ~= true then return end
  local bar = read(function() return elv.Health end)
  if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then return end
  local portrait = read(function() return elv.Portrait3D end)
  if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then
    portrait = read(function() return elv.Portrait2D end)
  end
  if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then portrait = nil end
  return elv, bar, portrait
end)

Plate.RegisterPlateBarSource(function(plate)
  if type(ElvUI) ~= "table" then return end
  local elv = read(function() return plate.unitFrame end)
  if type(elv) ~= "table" or type(elv.UpdateAllElements) ~= "function" then return end
  local bar = read(function() return elv.Health end)
  if Plate.VisibleHealthBar(bar) then return bar, "ElvUI.unitFrame.Health" end
end)
