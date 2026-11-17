-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- CastPrediction: the estimated mana cost, shown on your own mana bar while you cast.
-- Copyright (c) 2026 Rogerio Camorim. GPL-3.0-or-later, see LICENSE.
--
-- From UNIT_SPELLCAST_START to its end, a segment marks the estimated cost. On Forever it
-- extends to the right of the current mana, illustrating mana already spent; on Retail it
-- extends back from the current mana, illustrating the cost yet to be paid.
--
-- The cost is the spell's own mana cost (GetSpellPowerCost), a plain number. The bar's maximum may be secret in
-- combat on WoW: Forever, so the segment is a StatusBar (it accepts secret values, no Lua math on them), anchored to
-- the mana bar's fill texture. Frames: ElvUI (ElvUF_Player.Power), EllesmereUI (.Power), then Blizzard's mana bar.
--
-- Instant spells and channels take their mana at once, so there is nothing to show before it goes.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local talents = BIT.Module("CastPrediction").Talents
local isRetail = talents and type(talents.IsRetail) == "function" and talents.IsRetail()

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local WHITE = "Interface\\Buttons\\WHITE8X8"
local COLOR = { 0.95, 0.35, 0.2, 0.85 }

local overlay -- { clip, bar, host }

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, r = pcall(issecretvalue, v)
  return ok and r or false
end

local function read(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, value = pcall(fn, ...)
  if ok and not isSecret(value) then return value end
end

local function enabled()
  if BIT.IsSwitchedOn and not BIT.IsSwitchedOn("CastPrediction") then return false end
  return BIT.Settings("CastPrediction").showManaCost ~= false
end

-- The spell's mana cost as a plain number, or nil (no mana cost, or the client won't say).
local function manaCost(spellID)
  local get = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
  local costs = read(get, spellID)
  if type(costs) ~= "table" then return nil end
  for _, entry in ipairs(costs) do
    if type(entry) == "table" and entry.type == MANA then
      local cost = entry.cost
      if type(cost) == "number" and not isSecret(cost) and cost > 0 then return cost end
    end
  end
end

local function usableBar(bar)
  return type(bar) == "table" and read(bar.IsForbidden, bar) ~= true and read(bar.IsVisible, bar) == true
    and read(bar.GetObjectType, bar) == "StatusBar"
end

-- The player's mana bar, from whichever unit frame is on screen.
local function playerManaBar()
  local elv = type(ElvUI) == "table" and _G.ElvUF_Player
  if type(elv) == "table" and usableBar(elv.Power) then return elv.Power end
  local eui = _G.EllesmereUIUnitFrames_Player
  if type(eui) == "table" and usableBar(eui.Power) then return eui.Power end
  local frame = _G.PlayerFrame
  local content = type(frame) == "table" and frame.PlayerFrameContent
  local main = type(content) == "table" and content.PlayerFrameContentMain
  local area = type(main) == "table" and main.ManaBarArea
  local bar = type(area) == "table" and area.ManaBar
  if usableBar(bar) then return bar end
  if usableBar(_G.PlayerFrameManaBar) then return _G.PlayerFrameManaBar end
end

local function build(host)
  if overlay and overlay.host == host then return overlay end
  if not overlay then
    local clip = CreateFrame("Frame", nil, host)
    clip:SetClipsChildren(true)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3], COLOR[4])
    bar:SetReverseFill(isRetail and true or false)
    overlay = { clip = clip, bar = bar }
  end
  overlay.host = host
  overlay.clip:SetParent(host)
  overlay.clip:ClearAllPoints()
  overlay.clip:SetAllPoints(host)
  overlay.clip:SetFrameLevel(host:GetFrameLevel() + 2)
  return overlay
end

local function hide()
  if overlay then overlay.clip:Hide() end
end

local function show(cost)
  local host = playerManaBar()
  if not host then return hide() end
  local o = build(host)
  local fill = read(host.GetStatusBarTexture, host)
  if not fill then return hide() end
  local width = read(host.GetWidth, host)
  local ok = pcall(function()
    o.bar:ClearAllPoints()
    if isRetail then
      o.bar:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
      o.bar:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    else
      o.bar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
      o.bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
    end
    o.bar:SetWidth(type(width) == "number" and width > 0 and width or 100)
    o.bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    o.bar:SetValue(cost)
  end)
  if ok then o.clip:Show() else hide() end
end

-- The spell on the cast bar, when the event's own spell id is withheld.
local function castingSpellID()
  if type(UnitCastingInfo) ~= "function" then return end
  local ok, _, _, _, _, _, _, _, _, spellID = pcall(UnitCastingInfo, "player")
  if ok and type(spellID) == "number" and not isSecret(spellID) then return spellID end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
for _, event in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START" }) do
  frame:RegisterUnitEvent(event, "player")
end
local shownCast -- the cast GUID the segment is shown for, when the client gives a readable one

frame:SetScript("OnEvent", function(_, event, _, castGUID, spellID)
  if event == "PLAYER_LOGIN" then
    BIT.Settings("CastPrediction", { showManaCost = true }) -- the option's default, before the settings tab reads it
    return
  end
  if type(castGUID) ~= "string" or isSecret(castGUID) then castGUID = nil end
  if event ~= "UNIT_SPELLCAST_START" then
    -- Pressing another spell during a cast fires FAILED (and an instant one SUCCEEDED) with its own cast GUID
    -- while the first cast goes on: only the end of the cast that is shown hides the segment.
    if shownCast and castGUID and castGUID ~= shownCast
      and (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED") then return end
    shownCast = nil
    return hide()
  end
  shownCast = castGUID
  if not enabled() then return hide() end
  if type(spellID) ~= "number" or isSecret(spellID) then spellID = castingSpellID() end
  local cost = spellID and manaCost(spellID)
  if cost then show(cost) else hide() end
end)
