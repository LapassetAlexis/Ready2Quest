-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- HydraUI: gives the marks that sit on a health bar (DoT kill marks, shields, heals, combo dots) HydraUI's own unit
-- frames and nameplates. Hooks into Core/PlateLayout.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- HydraUI's frames (from its source, version 3.02): a unit frame is the global "HydraUI Player" / "HydraUI Target" /
-- "HydraUI Focus" (names with a space; the target's frame also serves any other unit) with the bar at .Health, and
-- Blizzard's own frame is hidden. A nameplate keeps Blizzard's UnitFrame alive and visible, strips only its artwork,
-- and hangs HydraUI's own button, plate._unitFrame, on Blizzard's health bar: that button's bar (.Health) is the one
-- on screen, with its own width and height, so the marks go there and not on Blizzard's bar underneath.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local Plate = BIT.Plate
local read = Plate.Read

local function loaded()
  local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  return read(isLoaded, "HydraUI") == true
end

local PART = { player = "Player", focus = "Focus", target = "Target" }

Plate.RegisterUnitFrameSource(function(_, part)
  if PART[string.lower(part)] ~= part or not loaded() then return end
  local hydra = _G["HydraUI " .. part]
  if type(hydra) ~= "table" or read(hydra.IsForbidden, hydra) == true or read(hydra.IsVisible, hydra) ~= true then return end
  local bar = read(function() return hydra.Health end)
  if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then return end
  return hydra, bar, nil
end)

Plate.RegisterPlateBarSource(function(plate)
  local hydra = read(function() return plate._unitFrame end)
  if type(hydra) ~= "table" or not loaded() then return end
  local bar = read(function() return hydra.Health end)
  if Plate.VisibleHealthBar(bar) then return bar, "HydraUI._unitFrame.Health" end
end)
