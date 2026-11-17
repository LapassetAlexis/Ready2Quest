-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the German texts of the Range tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT.RegisterLocale("deDE", {
  -- the live preview and its TRY IT block
  ["Simulate: out of range"] = "Außer Reichweite simulieren",
  ["Simulate: no nameplate"] = "Ohne Namensplakette simulieren",
  ["Preview the target without a visible nameplate."] = "Das Ziel ohne sichtbare Namensplakette in der Vorschau anzeigen.",
  ["No nameplate - marker hidden"] = "Keine Namensplakette - Markierung verborgen",
  ["The preview only: the red X while it is checked, the green checkmark while it is not."] =
    "Nur für die Vorschau: das rote X, solange das Feld angehakt ist, sonst das grüne Häkchen.",
  ["In range - the green checkmark"] = "In Reichweite - das grüne Häkchen",
  ["Out of range - the red X"] = "Außer Reichweite - das rote X",
  ["%s (off on your target)"] = "%s (am Ziel aus)",
  ["Grey and dim out of range"] = "Grau und abgedunkelt außer Reichweite",
  ["Left alone - the dimming is off"] = "Unverändert - das Abdunkeln ist aus",
  ["Its own colours in range"] = "Eigene Farben in Reichweite",
  ["A sample only: the mark and the dimming happen on your own target and bars."] =
    "Nur ein Beispiel: Markierung und Abdunkeln gelten für Euer Ziel und Eure Aktionsleisten.",

  -- the tabs
  ["Icon"] = "Symbol",
  ["Action bar"] = "Aktionsleiste",

  -- the Icon tab
  ["Checkmark in range"] = "Häkchen in Reichweite",
  ["The green checkmark over your target while one of the measuring spells reaches it."] =
    "Das grüne Häkchen über Eurem Ziel, solange einer der Messzauber es erreicht.",
  ["Red X out of range"] = "Rotes X außer Reichweite",
  ["The red X over your target while none of the measuring spells reaches it."] =
    "Das rote X über Eurem Ziel, solange keiner der Messzauber es erreicht.",
  ["Beside the target frame, even with a nameplate"] = "Neben dem Zielfenster, auch mit Namensplakette",
  ["The mark sits beside the target frame instead of above the target's nameplate. Without a target frame on screen it stays above the nameplate."] =
    "Die Markierung sitzt neben dem Zielfenster statt über der Namensplakette des Ziels. Ist kein Zielfenster auf dem Bildschirm, bleibt sie über der Namensplakette.",
  ["Beside the target frame without a nameplate"] = "Neben dem Zielfenster ohne Namensplakette",
  ["Without a nameplate (nameplates off, the target off screen) the mark sits beside the target frame instead."] =
    "Ohne Namensplakette (Namensplaketten aus, Ziel außerhalb des Bildschirms) sitzt die Markierung stattdessen neben dem Zielfenster.",
  ["The mark's size in pixels."] = "Die Größe der Markierung in Pixeln.",
  ["Height above the bar"] = "Höhe über der Leiste",
  ["Pixels above the nameplate's health bar: over the row of debuff icons there."] =
    "Pixel über der Gesundheitsleiste der Namensplakette: über der dortigen Reihe der Debuff-Symbole.",

  -- the Action bar tab
  ["Grey out action bar icons"] = "Symbole der Aktionsleisten ausgrauen",
  ["While the target is out of an action's range its icon goes grey and dim, on top of the game's red key binding."] =
    "Solange das Ziel außer Reichweite einer Aktion ist, wird deren Symbol grau und abgedunkelt, zusätzlich zur roten Tastenbelegung des Spiels.",

  -- the Spell tab
  ["Measure by this spell"] = "Mit diesem Zauber messen",
  ["A spell name or id of your own to measure the range by; empty: your class's main attacks."] =
    "Ein eigener Zaubername oder eine eigene Zauber-ID für die Reichweitenmessung; leer: die Hauptangriffe Eurer Klasse.",
  ["Measured by: %s"] = "Gemessen mit: %s",
  ["no spell of this class"] = "kein Zauber dieser Klasse",

  -- the presets
  ["Bare"] = "Schlicht",
  ["%s preset applied."] = "Vorlage %s angewendet.",

  -- the appearance sample
  ["Range sample (not your target)"] = "Reichweiten-Beispiel (nicht Euer Ziel)",
  ["In range - above nameplate"] = "In Reichweite - über der Namensplakette",
  ["Out of range - beside target frame"] = "Außer Reichweite - neben dem Zielfenster",
})
