-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: spell power shares for spells whose damage or healing the client's
-- SpellEffect tables attach to a second spell (build 1.60.1.70790); see tools/make_linked_coefficients.py for how each
-- number is worked out. Generated; do not edit by hand. Copyright (c) 2026 Ironship. GPL-3.0-or-later.
-- Only fills spells SpellCoefficients.lua does not have; the same keys as there (d, o, h, ho).

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("SpellDamageInfo")

local linked = {
  [10]={o=0.336},  -- Blizzard
  [5740]={o=0.332},  -- Rain of Fire
  [6141]={o=0.336},  -- Blizzard
  [6219]={o=0.332},  -- Rain of Fire
  [8427]={o=0.336},  -- Blizzard
  [10185]={o=0.336},  -- Blizzard
  [10186]={o=0.336},  -- Blizzard
  [10187]={o=0.336},  -- Blizzard
  [11677]={o=0.332},  -- Rain of Fire
  [11678]={o=0.332},  -- Rain of Fire
  [20116]={o=0.336},  -- Consecration
  [20473]={d=0.429,h=0.429},  -- Holy Shock
  [20922]={o=0.336},  -- Consecration
  [20923]={o=0.336},  -- Consecration
  [20924]={o=0.336},  -- Consecration
  [20929]={d=0.429,h=0.429},  -- Holy Shock
  [20930]={d=0.429,h=0.429},  -- Holy Shock
  [26573]={o=0.336},  -- Consecration
  [408341]={d=0.143},  -- Fire Nova
  [408342]={d=0.143},  -- Fire Nova
  [408343]={d=0.143},  -- Fire Nova
  [408344]={d=0.143},  -- Fire Nova
  [408345]={d=0.143},  -- Fire Nova
  [1311606]={d=0.429,h=0.429},  -- Holy Shock
}

local forever = ns.SpellCoefficients and ns.SpellCoefficients.forever
if forever then
  for id, entry in pairs(linked) do
    if forever[id] == nil then forever[id] = entry end
  end
end
